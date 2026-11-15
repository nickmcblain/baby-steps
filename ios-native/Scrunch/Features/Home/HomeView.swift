import ScrunchCore
import SwiftUI

/// Port of app/(app)/(tabs)/index.tsx.
struct HomeView: View {
  @Environment(ConvexService.self) private var convex
  @Environment(AppRouter.self) private var router
  @Environment(ActiveBabyStore.self) private var activeBaby
  @Environment(TimerStore.self) private var timers
  @Environment(\.scenePhase) private var scenePhase

  @State private var babies = Live<[Baby]>()
  @State private var summary = Live<DaySummary>()
  @State private var dash = Live<Dashboard>()
  @State private var patterns = Live<SleepPatterns>()
  @State private var dayStart = WeekGrid.startOfLocalDay(Date().epochMs)
  @State private var now = Date().epochMs
  @State private var rangeEndMs = Date().epochMs

  private var babyId: BabyID? { activeBaby.babyId }

  private var baby: Baby? {
    babies.value?.first { $0.id == babyId } ?? summary.value?.baby
  }

  private var asleep: Bool {
    guard let babyId else { return false }
    return timers.session?.isAsleep(babyId: babyId) ?? false
  }

  private var sleeps: [PatternItem] { patterns.value?.sleeps ?? [] }

  private var napAt: EpochMs? {
    SleepOffer.predictedNapAt(sleeps: sleeps.map(SleepSegment.init), lastSleepEndMs: summary.value?.lastSleepEndMs)
  }

  /// Fresh until the dashboard has loaded, so nothing flashes on launch.
  private var freshness: HomeCopy.Freshness {
    guard let dash = dash.value, dash.baby.id == babyId, !asleep else { return .fresh }
    let last = HomeCopy.lastLoggedAt([dash.lastFeed, dash.lastNappy, dash.lastSleep, dash.lastTummy])
    return HomeCopy.freshness(lastLoggedAt: last, now: now)
  }

  var body: some View {
    ScreenScaffold(showsBack: false, clearDock: baby == nil) {
      if let list = babies.value, list.isEmpty {
        empty
      } else {
        content
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if let baby, babies.value?.isEmpty == false {
        QuickLogPanel(baby: baby, lastFeed: dash.value?.lastFeed, now: now)
          .padding(.horizontal, 16)
          .padding(.top, 8)
          .padding(.bottom, quickLogDockClearance)
          .background(alignment: .top) {
            LinearGradient(colors: [C.bg.opacity(0), C.bg], startPoint: .top, endPoint: .bottom)
              .frame(height: 24)
              .offset(y: -24)
          }
          .background(C.bg.ignoresSafeArea(edges: .bottom))
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await syncSideEffects() } }
    }
    .task { await babies.bind(API.babies.list(), convex) }
    .task(id: babyId.map { API.events.daySummary(babyId: $0, dayStart: dayStart, dayEnd: WeekGrid.addDays(dayStart, 1)).key }) {
      guard let babyId else { return }
      await summary.bind(API.events.daySummary(babyId: babyId, dayStart: dayStart, dayEnd: WeekGrid.addDays(dayStart, 1)), convex)
    }
    .task(id: babyId) {
      guard let babyId else { return }
      await dash.bind(API.events.dashboard(babyId), convex)
    }
    .task(id: babyId) {
      guard let babyId else { return }
      await patterns.bind(API.events.sleepPatterns(babyId: babyId, days: 14, rangeEndMs: rangeEndMs), convex)
    }
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(30))
        now = Date().epochMs
      }
    }
    .onChange(of: babies.value) { _, list in
      guard let list, let first = list.first else { return }
      if !list.contains(where: { $0.id == babyId }) { activeBaby.select(first.id) }
    }
    .task(id: SideEffectKey(baby: baby, napAt: napAt, asleep: asleep, lastFeed: dash.value?.lastFeed, lastNappy: dash.value?.lastNappy, sleepMinutes: summary.value?.sleepMinutes)) {
      await syncSideEffects()
    }
  }

  /// The floating dock's height, so the quick-log panel sits just above it.
  private let quickLogDockClearance: CGFloat = 72

  private struct SideEffectKey: Equatable {
    let baby: Baby?
    let napAt: EpochMs?
    let asleep: Bool
    let lastFeed: Event?
    let lastNappy: Event?
    let sleepMinutes: Double?
  }

  private func syncSideEffects() async {
    guard let baby, baby.id == babyId else { return }
    await Reminders.refreshNap(babyId: baby.id, babyName: baby.name, napAt: napAt, asleep: asleep)
    await Reminders.refreshFeed(baby: baby, lastFeedAt: dash.value?.lastFeed.map(FeedWindows.feedEndedAt))
    WidgetSync.push(GlanceSnapshot.make(
      babyName: baby.name,
      asleep: asleep,
      napAt: napAt,
      lastFeed: dash.value?.lastFeed,
      lastNappy: dash.value?.lastNappy,
      sleepMinutesToday: summary.value?.sleepMinutes ?? 0,
      now: Date().epochMs
    ))
    await Reminders.ensureWeeklyDigest(babyId: baby.id, babyName: baby.name)
  }

  // MARK: Empty

  private var empty: some View {
    VStack(alignment: .leading, spacing: 16) {
      brandHeader("Scrunch")
      EmptyState(
        symbol: "heart.fill",
        tint: C.rose,
        title: "Welcome to Scrunch",
        message: "Add your baby to start logging feeds, sleep and nappies. A partner can join later with a share code.",
        actionLabel: "Add your baby",
        action: { router.path.append(.newBaby) }
      )
    }
  }

  private func brandHeader(_ title: String) -> some View {
    HStack(spacing: 10) {
      if let baby {
        BabyAvatar(babyId: baby.id, name: baby.name, size: 32)
      } else {
        Image("BrandMark")
          .resizable()
          .frame(width: 28, height: 28)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          .accessibilityHidden(true)
      }
      Text(title)
        .font(.app(.displayBold, 26))
        .foregroundStyle(C.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
  }

  @ViewBuilder
  private func freshnessCard(_ baby: Baby) -> some View {
    switch freshness {
    case .noLogs:
      EmptyState(
        symbol: "drop.fill",
        title: HomeCopy.welcomeTitle(babyName: baby.name),
        message: HomeCopy.welcomeBody(babyName: baby.name)
      )
    case .stale(let lastLoggedAt):
      EmptyState(
        symbol: "clock.arrow.circlepath",
        tint: C.purple,
        title: HomeCopy.staleTitle(lastLoggedAt: lastLoggedAt, now: now),
        message: HomeCopy.staleBody,
        actionLabel: "Log now",
        action: { router.addLogOpen = true }
      )
    case .fresh:
      EmptyView()
    }
  }

  // MARK: Content

  @ViewBuilder
  private var content: some View {
    brandHeader(baby?.name ?? " ")

    if let baby {
      HStack(spacing: 8) {
        vital("Age", Format.age(dateOfBirth: baby.dateOfBirth, now: now)) { router.push(baby.id, .edit) }
        vital("Height", baby.heightCm.map { Format.height($0) } ?? "—") { router.push(baby.id, .height) }
        vital("Weight", Format.weight(baby.weightGrams, unit: .lb)) { router.push(baby.id, .weight) }
      }
      freshnessCard(baby)
      insightCard(baby)
    }

    WeekStrip(selectedDayStart: dayStart) { dayStart = $0 }

    sleepBlock

    HStack(alignment: .top, spacing: 10) {
      macro(
        value: summary.value?.feedCount ?? 0,
        goal: baby.map { Double(SleepGoals.typicalFeedCount(dateOfBirth: $0.dateOfBirth, now: now)) } ?? 6,
        unit: nil, label: "Feeds",
        last: HomeCopy.lastFeedStrip(dash.value?.lastFeed, now: now),
        color: C.teal, track: C.tealSoft, screen: .feedPatterns
      )
      macro(
        value: summary.value?.nappyCount ?? 0,
        goal: baby.map { Double(SleepGoals.typicalNappyCount(dateOfBirth: $0.dateOfBirth, now: now)) } ?? 6,
        unit: nil, label: "Nappies",
        last: HomeCopy.lastNappyStrip(dash.value?.lastNappy, now: now),
        color: C.peach, track: C.peachSoft, screen: .nappyPatterns
      )
      macro(
        value: jsRound(summary.value?.tummyMinutes ?? 0),
        goal: Double(SleepGoals.tummyGoalMinutes),
        unit: "min", label: "Tummy",
        last: HomeCopy.lastTummyStrip(dash.value?.lastTummy, now: now),
        color: C.sky, track: C.skySoft, screen: .tummyPatterns
      )
    }
    Text(HomeCopy.targetsFootnote)
      .font(.app(.body, 13))
      .foregroundStyle(C.muted)
      .padding(.horizontal, 8)
      .padding(.top, -6)

    if let baby {
      MilestonesCard(baby: baby)
    }
  }

  private func insightCard(_ baby: Baby) -> some View {
    let isToday = dayStart == WeekGrid.startOfLocalDay(now)
    let todayEvents = isToday ? summary.value?.events ?? [] : []
    let lastSleep = dash.value?.lastSleep
    let input = InsightInput(
      baby: baby,
      now: now,
      recentFeeds: todayEvents + [dash.value?.lastFeed].compactMap { $0 },
      lastNappy: dash.value?.lastNappy,
      lastSleepEndMs: lastSleep.map { $0.loggedAt + ($0.durationMinutes ?? 0) * minuteMs },
      asleep: asleep
    )
    // The quick-log panel already shows the last and next breast side.
    let timerRunning = !asleep && timers.session.map { $0.babyId == baby.id && $0.isRunning } ?? false
    let caughtUp = isToday && !timerRunning && Insights.allCaughtUp(input)
    return InsightCard(insights: Insights.all(input).filter { $0.kind != .breastSide }, caughtUp: caughtUp) { kind in
      switch kind {
      case .nextFeed, .breastSide: router.push(baby.id, .feedPatterns)
      case .lastNappy: router.push(baby.id, .nappyPatterns)
      case .awake: router.push(baby.id, .sleepPatterns)
      case .tonightTog: router.push(baby.id, .clothing)
      }
    } onAsk: {
      router.push(baby.id, .ask())
    }
  }

  @ViewBuilder
  private var sleepBlock: some View {
    let rhythm = baby.map {
      DayRhythmEngine.recommendedDay(
        dateOfBirth: $0.dateOfBirth,
        now: now,
        sleeps: sleeps.map { RhythmSleep(startMs: $0.startMs, endMs: $0.endMs) },
        night: $0.nightWindow
      )
    }
    // Only count down when recent logs back it up; otherwise "Next nap · Now" reads as live.
    let nextWindow = freshness == .fresh ? rhythm.flatMap { DayRhythmEngine.nextSleepCountdown($0.segments, now: now) } : nil
    let sleepH = (summary.value?.sleepMinutes ?? 0) / 60

    VStack(spacing: 0) {
      if let nextWindow, let baby {
        Button { router.push(baby.id, .sleepTimer) } label: {
          HStack {
            Text(HomeCopy.countdownLabel(nextWindow)).font(.app(.medium, 13)).foregroundStyle(C.purple)
            Spacer()
            Text(HomeCopy.countdown(nextWindow.inMs)).font(.app(.bold, 16)).foregroundStyle(C.ink)
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 12)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }

      VStack(alignment: .leading, spacing: 0) {
        Button {
          if let baby { router.push(baby.id, .sleepPatterns) }
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(HomeCopy.hours(sleepH)).font(.app(.displayBold, 28)).foregroundStyle(C.ink)
            Text("Sleep today").font(.app(.medium, 15)).foregroundStyle(C.muted)
            if let baby {
              let range = SleepGoals.sleepDurationRange(dateOfBirth: baby.dateOfBirth, now: now)
              Text("Typical at this age: \(jsNumber(range.lowHours))–\(jsNumber(range.highHours))h")
                .font(.app(.body, 13)).foregroundStyle(C.muted)
            }
          }
          .padding(20)
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if let rhythm, let baby {
          DayRhythmBar(rhythm: rhythm, now: now) { router.push(baby.id, .sleepPatterns) }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
        LastStrip(text: HomeCopy.lastSleepStrip(dash.value?.lastSleep, now: now), inset: 20, reservesTwoLines: false)
      }
      .background(C.card)
      .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
      .cardShadow()
    }
    .padding(6)
    .padding(.top, nextWindow == nil ? 0 : -6)
    .background(C.purpleSoft, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
  }

  private func vital(_ label: String, _ value: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(spacing: 2) {
        Text(label).font(.app(.medium, 11, relativeTo: .caption2)).foregroundStyle(C.muted)
        Text(value).font(.app(.bold, 14)).foregroundStyle(C.ink).lineLimit(1).minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity)
      .padding(10)
      .background(C.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      .cardShadow()
    }
    .buttonStyle(PressScale())
    .accessibilityElement(children: .combine)
  }

  private func macro(
    value: Double, goal: Double, unit: String?, label: String, last: String,
    color: Color, track: Color, screen: BabyScreen
  ) -> some View {
    Button {
      if let baby { router.push(baby.id, screen) }
    } label: {
      VStack(alignment: .leading, spacing: 0) {
        VStack(alignment: .leading, spacing: 8) {
          ProgressRing(progress: goal > 0 ? value / goal : 0, color: color, track: track)
          (Text(jsNumber(value)).font(.app(.bold, 16)).foregroundStyle(C.ink)
            + Text(" / \(jsNumber(goal))\(unit.map { " \($0)" } ?? "")").font(.app(.medium, 13)).foregroundStyle(C.muted))
          Text(label).font(.app(.body, 12)).foregroundStyle(C.muted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        LastStrip(text: last)
      }
      .background(C.card)
      .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
      .cardShadow()
    }
    .buttonStyle(PressScale())
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label): \(jsNumber(value)) of \(jsNumber(goal))\(unit.map { " \($0)" } ?? ""). \(last)")
  }
}
