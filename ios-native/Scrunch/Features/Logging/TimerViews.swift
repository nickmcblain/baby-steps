import ScrunchCore
import SwiftUI

/// Shared plumbing for the four timer screens (sleep/tummy/feed/pump timer.tsx).
@MainActor
private struct TimerScreenModel {
  let babyId: BabyID
  let kind: TimerKind
  let timers: TimerStore

  var session: TimerSession? { timers.session(for: kind, babyId: babyId) }

  func fresh(babyName: String?) -> TimerSession {
    session ?? TimerSession(kind: kind, babyId: babyId, babyName: babyName, now: Date().epochMs)
  }
}

private struct ClockText: View {
  let session: TimerSession?
  let value: (TimerSession, EpochMs) -> Double
  let font: Font
  let color: Color

  var body: some View {
    if let session, session.isRunning {
      SwiftUI.TimelineView(.periodic(from: .now, by: 0.2)) { context in
        label(value(session, context.date.epochMs))
      }
    } else {
      label(session.map { value($0, Date().epochMs) } ?? 0)
    }
  }

  private func label(_ ms: Double) -> some View {
    Text(TimerClock.format(ms))
      .font(font)
      .monospacedDigit()
      .foregroundStyle(color)
      .contentTransition(.numericText())
  }
}

private struct TimerFooter: View {
  let doneLabel: String
  let canFinish: Bool
  let showReset: Bool
  let onDone: () async -> Void
  let onSkip: () async -> Void
  let onReset: () async -> Void

  var body: some View {
    VStack(spacing: 12) {
      PrimaryButton(label: doneLabel, disabled: !canFinish) { await onDone() }
      Button { Task { await onSkip() } } label: {
        Text("Skip to manual entry").font(.app(.medium, 15)).foregroundStyle(C.muted).padding(.vertical, 8)
      }
      .accessibilityAddTraits(.isLink)
      if showReset {
        Button { Task { await onReset() } } label: {
          Text("Reset").font(.app(.medium, 15)).foregroundStyle(C.muted).padding(.vertical, 8)
        }
      }
    }
    .padding(.top, 8)
  }
}

// MARK: - Sleep / tummy

struct DurationTimerView: View {
  let babyId: BabyID
  let kind: TimerKind

  @Environment(ConvexService.self) private var convex
  @Environment(AppRouter.self) private var router
  @Environment(TimerStore.self) private var timers
  @Environment(\.scenePhase) private var scenePhase
  @State private var dash = Live<Dashboard>()
  @State private var liveError: String?

  private var model: TimerScreenModel { TimerScreenModel(babyId: babyId, kind: kind, timers: timers) }
  private var isSleep: Bool { kind == .sleep }
  private var accent: Color { isSleep ? C.purple : C.sky }

  var body: some View {
    let session = model.session
    let running = session?.isRunning ?? false
    let elapsed = session?.elapsed(now: Date().epochMs) ?? 0

    ScreenScaffold {
      ScreenTitle(isSleep ? "Sleep timer" : "Tummy time")
      Text(isSleep
        ? "Start when they nod off. Keeps timing on the Lock Screen / Dynamic Island while the app is away."
        : "Start when they go on their tummy. Keeps timing on the Lock Screen / Dynamic Island while the app is away.")
        .font(.app(.body, 15)).foregroundStyle(C.muted).lineSpacing(4).padding(.top, -4)

      Button { Task { await toggle() } } label: {
        VStack(spacing: 10) {
          ClockText(session: session, value: { $0.elapsed(now: $1) }, font: .app(.displayBold, 48), color: running ? .white : C.ink)
          Text(running ? "Pause" : elapsed > 0 ? "Resume" : "Start")
            .font(.app(.medium, 15))
            .foregroundStyle(running ? .white.opacity(0.9) : accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(running ? accent : C.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .cardShadow()
      }
      .buttonStyle(PressScale())
      .sensoryFeedback(.impact(weight: .light), trigger: running)

      TimerFooter(
        doneLabel: "Done — confirm details",
        canFinish: session?.canFinish(now: Date().epochMs) ?? false,
        showReset: elapsed > 0 && !running,
        onDone: finish,
        onSkip: skip,
        onReset: reset
      )
    }
    .task { await dash.bind(API.events.dashboard(babyId), convex) }
    .task {
      if let session = model.session { await push(session) }
    }
    .task(id: dash.value?.baby) {
      if running { await syncReminders() }
    }
    .alert("Lock Screen timer unavailable", isPresented: Binding(get: { liveError != nil }, set: { if !$0 { liveError = nil } })) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(liveError ?? "")
    }
  }

  private func push(_ session: TimerSession) async {
    let error = await timers.update(session)
    if session.isRunning, let error {
      liveError = isSleep
        ? error
        : "Could not start Dynamic Island / Lock Screen timer."
    }
  }

  private func syncReminders() async {
    guard isSleep, let data = dash.value else { return }
    await Reminders.refreshFeed(baby: data.baby, lastFeedAt: data.lastFeed.map(FeedWindows.feedEndedAt))
  }

  private func toggle() async {
    var session = model.fresh(babyName: dash.value?.baby.name)
    session.toggle(now: Date().epochMs)
    await push(session)
    await syncReminders()
  }

  private func reset() async {
    await timers.stop()
    await syncReminders()
  }

  private func finish() async {
    guard var session = model.session else { return }
    session.pause(now: Date().epochMs)
    guard let handoff = session.handoff() else {
      await push(session)
      return
    }
    await timers.stop()
    await syncReminders()
    router.replaceTop(babyId, isSleep ? .sleepManual(handoff) : .tummyManual(handoff))
  }

  private func skip() async {
    if model.session != nil { await timers.stop() }
    await syncReminders()
    router.replaceTop(babyId, isSleep ? .sleepManual(nil) : .tummyManual(nil))
  }
}

// MARK: - Feed / pump

struct FeedTimerView: View {
  let babyId: BabyID
  let kind: TimerKind

  @Environment(ConvexService.self) private var convex
  @Environment(AppRouter.self) private var router
  @Environment(TimerStore.self) private var timers
  @State private var baby = Live<Baby>()
  @State private var liveError: String?

  private var model: TimerScreenModel { TimerScreenModel(babyId: babyId, kind: kind, timers: timers) }
  private var isPump: Bool { kind == .pump }

  var body: some View {
    let session = model.session
    let now = Date().epochMs
    let leftMs = session?.sideElapsed(.left, now: now) ?? 0
    let rightMs = session?.sideElapsed(.right, now: now) ?? 0

    ScreenScaffold {
      ScreenTitle(isPump ? "Pump" : "Timer")
      Text("Time one side at a time. Island keeps the active side running if you leave the app.")
        .font(.app(.body, 15)).foregroundStyle(C.muted).lineSpacing(4).padding(.top, -4)

      HStack(spacing: 12) {
        sideCard("Left", .left, session: session, ms: leftMs)
        sideCard("Right", .right, session: session, ms: rightMs)
      }

      TimerFooter(
        doneLabel: isPump ? "Done — add amount" : "Done — fill in details",
        canFinish: session?.canFinish(now: now) ?? false,
        showReset: (leftMs > 0 || rightMs > 0) && session?.activeSide == nil,
        onDone: finish,
        onSkip: skip,
        onReset: { await timers.stop() }
      )
    }
    .task { await baby.bind(API.babies.get(babyId), convex) }
    .task {
      if let session = model.session { await push(session) }
    }
    .alert("Lock Screen timer unavailable", isPresented: Binding(get: { liveError != nil }, set: { if !$0 { liveError = nil } })) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(liveError ?? "")
    }
  }

  private func sideCard(_ label: String, _ side: TimerSide, session: TimerSession?, ms: Double) -> some View {
    let running = session?.activeSide == side && session?.isRunning == true
    return Button { Task { await tap(side) } } label: {
      VStack(spacing: 8) {
        Text(label.uppercased())
          .font(.app(.bold, 13))
          .tracking(0.6)
          .foregroundStyle(running ? .white.opacity(0.85) : C.muted)
        ClockText(session: session, value: { $0.sideElapsed(side, now: $1) }, font: .app(.displayBold, 36), color: running ? .white : C.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Text(running ? "Pause" : ms > 0 ? "Resume" : "Start")
          .font(.app(.medium, 14))
          .foregroundStyle(running ? .white.opacity(0.9) : C.tealDark)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 28)
      .padding(.horizontal, 12)
      .background(running ? C.teal : C.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
      .cardShadow()
    }
    .buttonStyle(PressScale())
    .sensoryFeedback(.impact(weight: .light), trigger: running)
    .accessibilityLabel("\(label) side")
  }

  private func push(_ session: TimerSession) async {
    let error = await timers.update(session)
    if session.isRunning, let error {
      liveError = isPump ? "Could not start Dynamic Island / Lock Screen timer." : error
    }
  }

  private func tap(_ side: TimerSide) async {
    var session = model.fresh(babyName: baby.value?.name)
    session.tapSide(side, now: Date().epochMs)
    await push(session)
  }

  private func finish() async {
    guard var session = model.session else { return }
    session.pause(now: Date().epochMs)
    guard let handoff = session.handoff() else {
      await push(session)
      return
    }
    await timers.stop()
    router.replaceTop(babyId, isPump ? .pumpManual(handoff) : .feedManual(handoff))
  }

  private func skip() async {
    if model.session != nil { await timers.stop() }
    router.replaceTop(babyId, isPump ? .pumpManual(nil) : .feedManual(nil))
  }
}
