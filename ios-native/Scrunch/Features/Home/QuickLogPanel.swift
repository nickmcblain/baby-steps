import ScrunchCore
import SwiftUI

/// Home's thumb-reach logging: one tap starts a breastfeed or sleep, or logs a nappy.
/// While a timer runs it shows here with side switching, "−5 min" and Done.
struct QuickLogPanel: View {
  let baby: Baby
  let lastFeed: Event?
  let now: EpochMs

  @Environment(ConvexService.self) private var convex
  @Environment(AppRouter.self) private var router
  @Environment(TimerStore.self) private var timers
  @Environment(UndoCenter.self) private var undo
  @State private var savingNappy: QuickLog.Nappy?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let session = timers.session {
        RunningTimerControls(session: session, showsBabyName: session.babyId != baby.id)
      } else {
        starters
      }
      nappyRow
    }
    .padding(12)
    .background(C.card, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
    .cardShadow(opacity: 0.12)
  }

  // MARK: Starters

  private var starters: some View {
    let suggested = QuickLog.suggestedSide(lastFeed: lastFeed)
    return VStack(alignment: .leading, spacing: 8) {
      Text(QuickLog.lastSideLine(lastFeed: lastFeed, now: now) ?? "Tap to start a timer")
        .font(.app(.medium, 13))
        .foregroundStyle(C.muted)
        .padding(.leading, 4)
      HStack(spacing: 8) {
        starter("Left", detail: suggested == .left ? "Next side" : "Breastfeed", symbol: "play.fill", filled: suggested == .left, tint: C.teal, soft: C.tealSoft, ink: C.tealDark) {
          await start(.feed, side: .left)
        }
        starter("Right", detail: suggested == .right ? "Next side" : "Breastfeed", symbol: "play.fill", filled: suggested == .right, tint: C.teal, soft: C.tealSoft, ink: C.tealDark) {
          await start(.feed, side: .right)
        }
        starter("Sleep", detail: "Start timer", symbol: "moon.fill", filled: false, tint: C.purple, soft: C.purpleSoft, ink: C.purple) {
          await start(.sleep)
        }
      }
    }
  }

  private func starter(
    _ label: String, detail: String, symbol: String, filled: Bool,
    tint: Color, soft: Color, ink: Color, action: @escaping () async -> Void
  ) -> some View {
    Button { Task { await action() } } label: {
      HStack(spacing: 8) {
        Image(systemName: symbol)
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(filled ? C.onAccent : ink)
        VStack(alignment: .leading, spacing: 0) {
          Text(label).font(.app(.bold, 16)).foregroundStyle(filled ? C.onAccent : C.ink)
          Text(detail).font(.app(.medium, 11, relativeTo: .caption2)).foregroundStyle(filled ? C.onAccent.opacity(0.9) : ink)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity, minHeight: 60)
      .padding(.horizontal, 6)
      .background(filled ? tint : soft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .contentShape(Rectangle())
    }
    .buttonStyle(PressScale())
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label == "Sleep" ? "Start sleep timer" : "Start breastfeed, \(label.lowercased()) side")
    .accessibilityHint(filled ? "Suggested next side" : "")
  }

  private func start(_ kind: TimerKind, side: TimerSide = .left) async {
    guard timers.session == nil else { return }
    let session = TimerSession.started(kind: kind, side: side, babyId: baby.id, babyName: baby.name, now: Date().epochMs)
    let liveError = await timers.update(session)
    let message = QuickLog.startedToast(session)
    undo.show(UndoCenter.Toast(
      message: liveError == nil ? message : "\(message). Lock Screen timer is off in Settings.",
      undo: { [timers] in
        guard let current = timers.session, current.kind == kind, current.babyId == session.babyId else { return }
        await timers.stop()
      }
    ))
  }

  // MARK: Nappy

  private var nappyRow: some View {
    HStack(spacing: 8) {
      ForEach(QuickLog.Nappy.allCases, id: \.self) { nappy in
        Button { Task { await log(nappy) } } label: {
          ZStack {
            if savingNappy == nappy {
              ProgressView().tint(C.peach)
            } else {
              Text(nappy.label).font(.app(.bold, 15)).foregroundStyle(C.ink)
            }
          }
          .frame(maxWidth: .infinity, minHeight: 48)
          .background(C.peachSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .disabled(savingNappy != nil)
        .accessibilityLabel("Log \(nappy == .both ? "wet and dirty" : nappy.label.lowercased()) nappy")
      }
    }
  }

  private func log(_ nappy: QuickLog.Nappy) async {
    guard savingNappy == nil else { return }
    savingNappy = nappy
    defer { savingNappy = nil }
    let loggedAt = LoggedAt.nowSnapped()
    do {
      let id = try await convex.mutation(nappyCall(nappy, at: loggedAt))
      showSaved(nappy, saved: SavedLog(id: id, loggedAt: loggedAt))
    } catch {
      undo.show(UndoCenter.Toast(message: "Couldn’t log that nappy. Try again."))
    }
  }

  private func nappyCall(_ nappy: QuickLog.Nappy, at loggedAt: EpochMs) -> ConvexCall<EventID> {
    API.events.logNappy(babyId: baby.id, loggedAt: loggedAt, nappy: nappy.kind, weeSize: nappy.weeSize, pooSize: nappy.pooSize)
  }

  /// Fixing a fresh log re-saves it at the new time, then removes the original.
  private func showSaved(_ nappy: QuickLog.Nappy, saved: SavedLog) {
    undo.show(UndoCenter.Toast(
      message: QuickLog.savedCopy(nappy.loggedCopy, loggedAt: saved.loggedAt),
      undo: { [convex, undo] in
        do {
          try await convex.mutation(API.events.remove(saved.id))
        } catch {
          undo.show(UndoCenter.Toast(message: "Couldn’t undo. Delete it from Timeline."))
        }
      },
      shift: { [convex] minutes in
        let movedAt = QuickLog.shifted(saved.loggedAt, minutes: minutes)
        guard let movedId = try? await convex.mutation(nappyCall(nappy, at: movedAt)) else { return nil }
        try? await convex.mutation(API.events.remove(saved.id))
        saved.id = movedId
        saved.loggedAt = movedAt
        return QuickLog.savedCopy(nappy.loggedCopy, loggedAt: movedAt)
      }
    ))
  }

  @MainActor
  private final class SavedLog {
    var id: EventID
    var loggedAt: EpochMs
    init(id: EventID, loggedAt: EpochMs) {
      self.id = id
      self.loggedAt = loggedAt
    }
  }
}

/// The running timer, controllable from Home without opening the timer screen.
struct RunningTimerControls: View {
  let session: TimerSession
  var showsBabyName = false

  @Environment(AppRouter.self) private var router
  @Environment(TimerStore.self) private var timers
  @Environment(UndoCenter.self) private var undo

  private var accent: Color {
    switch session.kind {
    case .sleep: C.purple
    case .tummy: C.sky
    case .feed, .pump: C.teal
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Button { router.push(session.babyId, timerScreen) } label: {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 2) {
            Text(QuickLog.runningTitle(session) + (showsBabyName ? " · \(session.babyName ?? "")" : ""))
              .font(.app(.bold, 16)).foregroundStyle(C.ink).lineLimit(1)
            Text(QuickLog.startedCopy(session)).font(.app(.medium, 13)).foregroundStyle(C.muted)
          }
          Spacer(minLength: 8)
          RunningClock(session: session)
          Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(C.muted)
        }
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityHint("Opens the timer")

      StartShiftChips(session: session)

      HStack(spacing: 8) {
        if session.kind.isSided {
          sideButton(.left)
          sideButton(.right)
        } else {
          control(session.isRunning ? "Pause" : "Resume", symbol: session.isRunning ? "pause.fill" : "play.fill", filled: session.isRunning) {
            var next = session
            next.toggle(now: Date().epochMs)
            await timers.update(next)
          }
        }
        control("Done", symbol: "checkmark", filled: false) { await finish() }
      }
    }
  }

  private var timerScreen: BabyScreen {
    switch session.kind {
    case .sleep: .sleepTimer
    case .tummy: .tummyTimer
    case .feed: .feedTimer
    case .pump: .pumpTimer
    }
  }

  private func sideButton(_ side: TimerSide) -> some View {
    let active = session.activeSide == side && session.isRunning
    let label = side == .left ? "Left" : "Right"
    return control(label, symbol: active ? "pause.fill" : "play.fill", filled: active) {
      var next = session
      next.tapSide(side, now: Date().epochMs)
      await timers.update(next)
    }
    .accessibilityLabel(active ? "Pause \(label.lowercased()) side" : "Feed on \(label.lowercased()) side")
  }

  private func control(_ label: String, symbol: String, filled: Bool, action: @escaping () async -> Void) -> some View {
    Button { Task { await action() } } label: {
      HStack(spacing: 6) {
        Image(systemName: symbol).font(.system(size: 16, weight: .bold))
        Text(label).font(.app(.bold, 16))
      }
      .foregroundStyle(filled ? C.onAccent : C.ink)
      .frame(maxWidth: .infinity, minHeight: 52)
      .background(filled ? accent : C.bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      .contentShape(Rectangle())
    }
    .buttonStyle(PressScale())
  }

  private func finish() async {
    var next = session
    next.pause(now: Date().epochMs)
    let handoff = next.handoff()
    await timers.stop()
    guard let handoff else {
      undo.show(UndoCenter.Toast(message: "Too short to save. Timer cleared."))
      return
    }
    let screen: BabyScreen = switch session.kind {
    case .sleep: .sleepManual(handoff)
    case .tummy: .tummyManual(handoff)
    case .feed: .feedManual(handoff)
    case .pump: .pumpManual(handoff)
    }
    router.push(session.babyId, screen)
  }
}

struct RunningClock: View {
  let session: TimerSession

  var body: some View {
    Group {
      if session.isRunning {
        SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
          label(session.elapsed(now: context.date.epochMs))
        }
      } else {
        label(session.elapsed(now: Date().epochMs))
      }
    }
  }

  private func label(_ ms: Double) -> some View {
    Text(TimerClock.format(ms))
      .font(.app(.displayBold, 26))
      .monospacedDigit()
      .foregroundStyle(C.ink)
  }
}

/// "Started 14:32" fixes: each chip moves the start earlier and adds the time.
struct StartShiftChips: View {
  let session: TimerSession

  @Environment(TimerStore.self) private var timers

  var body: some View {
    HStack(spacing: 8) {
      Text("Forgot to start?").font(.app(.medium, 13)).foregroundStyle(C.muted)
      Spacer(minLength: 0)
      ForEach(QuickLog.shiftMinutes, id: \.self) { minutes in
        Button {
          Task {
            var next = session
            next.shiftStart(byMinutes: minutes)
            await timers.update(next)
          }
        } label: {
          Text("−\(minutes) min")
            .font(.app(.bold, 14))
            .foregroundStyle(C.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(C.bg, in: Capsule())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel("Started \(minutes) minutes earlier")
      }
    }
  }
}
