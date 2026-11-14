import ScrunchCore
import SwiftUI

/// Port of app/(app)/baby/[id]/index.tsx.
struct BabyHomeView: View {
  let babyId: BabyID

  @Environment(ConvexService.self) private var convex
  @Environment(AppRouter.self) private var router
  @Environment(\.scenePhase) private var scenePhase
  @State private var data = Live<Dashboard>()
  @State private var sheet: LogChoice?
  @Environment(\.dynamicTypeSize) private var typeSize

  enum LogChoice: String, Identifiable {
    case feed, sleep, tummy
    var id: String { rawValue }
  }

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      ScreenScaffold {
        Button { router.push(babyId, .edit) } label: {
          Text("Edit")
            .font(.app(.bold, 13))
            .foregroundStyle(C.ink)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .frame(minWidth: 44, minHeight: 44)
            .background(C.card, in: Capsule())
            .cardShadow()
        }
        .buttonStyle(PressScale())
        .accessibilityHint("Edit baby details")
      } content: {
        if let data = data.value {
          content(data)
        } else {
          ScreenTitle("Loading…")
        }
      }

      CircleIconButton(systemImage: "bubble.left.and.text.bubble.right.fill", label: "Ask", spokenNames: ["Chat", "Question"]) {
        router.push(babyId, .ask(question: nil))
      }
      .padding(.trailing, 16)
      .padding(.bottom, 8)
    }
    .task { await data.bind(API.events.dashboard(babyId), convex) }
    .task(id: reminderKey) { await syncFeedReminder() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await syncFeedReminder() } }
    }
    .sheet(item: $sheet) { choice in
      choiceSheet(choice)
        .adaptiveDetents([.height(choice == .tummy ? 190 : 260)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(C.bg)
    }
  }

  private struct ReminderKey: Equatable {
    let baby: Baby
    let lastFeedAt: EpochMs?
  }

  private var reminderKey: ReminderKey? {
    guard let value = data.value else { return nil }
    return ReminderKey(baby: value.baby, lastFeedAt: value.lastFeed.map(FeedWindows.feedEndedAt))
  }

  private func syncFeedReminder() async {
    guard let key = reminderKey else { return }
    await Reminders.refreshFeed(baby: key.baby, lastFeedAt: key.lastFeedAt)
  }

  @ViewBuilder
  private func content(_ data: Dashboard) -> some View {
    let baby = data.baby
    let now = Date().epochMs

    AdaptiveStack(alignment: .firstTextBaseline, spacing: 12) {
      ScreenTitle(baby.name).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
      Spacer(minLength: 0)
      Text(Format.age(dateOfBirth: baby.dateOfBirth, now: now).uppercased())
        .font(.app(.bold, 15))
        .tracking(0.7)
        .foregroundStyle(C.tealDark)
        .fixedSize(horizontal: !typeSize.isAccessibilitySize, vertical: true)
        .accessibilityLabel("Age \(Format.age(dateOfBirth: baby.dateOfBirth, now: now))")
    }

    AdaptiveStack(spacing: 12) {
      statusTile("Weight", Format.weight(baby.weightGrams), tint: C.tealSoft) { router.push(babyId, .weight) }
      statusTile("Height", baby.heightCm.map { Format.height($0) } ?? "—", tint: C.skySoft) { router.push(babyId, .height) }
    }

    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
      actionTile("Feed", "drop.fill", C.teal, last(data.lastFeed, now)) { sheet = .feed }
      actionTile("Sleep", "moon.fill", C.purple, last(data.lastSleep, now)) { sheet = .sleep }
      actionTile("Tummy", "figure.arms.open", C.sky, last(data.lastTummy, now)) { sheet = .tummy }
      actionTile("Nappy", "circle.grid.2x2.fill", C.peach, last(data.lastNappy, now)) { router.push(babyId, .nappy) }
      actionTile("Clothing", "thermometer.medium", C.tealDark, nil) { router.push(babyId, .clothing) }
      actionTile("Timeline", "list.bullet.rectangle.fill", C.amber, nil) { router.push(babyId, .timeline) }
    }
    .padding(.bottom, 64)
  }

  private func last(_ event: Event?, _ now: EpochMs) -> String? {
    event.map { "\(Format.relative($0.loggedAt, now: now)) · \(EventCopy.title($0))" }
  }

  private func statusTile(_ label: String, _ value: String, tint: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 4) {
        Text(label).font(.app(.medium, 13)).foregroundStyle(C.muted)
        Text(value).font(.app(.displayBold, 22)).foregroundStyle(C.ink).lineLimit(1).minimumScaleFactor(0.7)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(tint, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
    }
    .buttonStyle(PressScale())
    .accessibilityElement(children: .combine)
  }

  private func actionTile(_ label: String, _ symbol: String, _ color: Color, _ last: String?, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 12) {
        IconWell(systemImage: symbol, tint: color, size: 48)
        Text(label).font(.app(.bold, 18)).foregroundStyle(C.ink)
        Text(last ?? " ")
          .font(.app(.body, 13))
          .foregroundStyle(C.muted)
          .lineLimit(typeSize.isAccessibilitySize ? 8 : 2, reservesSpace: !typeSize.isAccessibilitySize)
          .multilineTextAlignment(.leading)
      }
      .padding(18)
      .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
      .background(C.card, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
      .cardShadow()
    }
    .buttonStyle(PressScale())
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
    .accessibilityInputLabels([label])
  }

  private func choiceSheet(_ choice: LogChoice) -> some View {
    let (primary, soft): (Color, Color) = switch choice {
    case .feed: (C.teal, C.tealSoft)
    case .sleep: (C.purple, C.purpleSoft)
    case .tummy: (C.sky, C.skySoft)
    }
    let screens: (timer: BabyScreen, manual: BabyScreen, patterns: (String, BabyScreen)?) = switch choice {
    case .feed: (.feedTimer, .feedManual(nil), ("Feed patterns", .feedPatterns))
    case .sleep: (.sleepTimer, .sleepManual(nil), ("Sleep patterns", .sleepPatterns))
    case .tummy: (.tummyTimer, .tummyManual(nil), nil)
    }
    return VStack(spacing: 10) {
      sheetButton("Start timer", fill: primary, ink: .white) { open(screens.timer) }
      sheetButton("Log manually", fill: soft, ink: C.ink) { open(screens.manual) }
      if let patterns = screens.patterns {
        sheetButton(patterns.0, fill: soft, ink: C.ink) { open(patterns.1) }
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 28)
    .frame(maxHeight: .infinity, alignment: .top)
  }

  private func sheetButton(_ label: String, fill: Color, ink: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(label)
        .font(.app(.bold, 16))
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    .buttonStyle(PressScale())
  }

  private func open(_ screen: BabyScreen) {
    sheet = nil
    router.push(babyId, screen)
  }
}
