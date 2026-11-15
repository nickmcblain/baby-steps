import ScrunchCore
import SwiftUI

private func trimmedOrNil(_ value: String) -> String? {
  let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
  return trimmed.isEmpty ? nil : trimmed
}

private func number(_ value: String) -> Double? {
  Double(value.trimmingCharacters(in: .whitespaces))
}

private func initialMinutes(_ handoff: TimerSession.Handoff?) -> String {
  guard let minutes = handoff?.minutes, minutes > 0 else { return "" }
  return String(minutes)
}

struct SectionLabel: View {
  let text: LocalizedStringKey
  init(_ text: LocalizedStringKey) { self.text = text }

  var body: some View {
    Text(text)
      .textCase(.uppercase)
      .font(.app(.bold, 13))
      .tracking(0.6)
      .foregroundStyle(C.muted)
  }
}

struct Hint: View {
  let text: LocalizedStringKey
  init(_ text: LocalizedStringKey) { self.text = text }

  var body: some View {
    Text(text).font(.app(.body, 15)).foregroundStyle(C.muted).lineSpacing(4).padding(.top, -4)
  }
}

/// Port of feed/manual.tsx.
struct FeedManualView: View {
  let babyId: BabyID
  let handoff: TimerSession.Handoff?

  @Environment(ConvexService.self) private var convex
  @Environment(SaveFeedback.self) private var saveFeedback
  @Environment(AppRouter.self) private var router
  @Environment(LogGate.self) private var gate
  @State private var baby = Live<Baby>()
  @State private var loggedAt: EpochMs
  @State private var kind: FeedKind = .breast
  @State private var side: Side
  @State private var minutes: String
  @State private var ml = ""
  @State private var milk: Milk = .formula
  private let units = DisplayFormat.current
  @State private var note: String
  @State private var alert: FormAlert?

  init(babyId: BabyID, handoff: TimerSession.Handoff?) {
    self.babyId = babyId
    self.handoff = handoff
    _loggedAt = State(initialValue: handoff.map { LoggedAt.snapToMinute($0.startedAt) } ?? LoggedAt.nowSnapped())
    _side = State(initialValue: handoff?.side ?? .left)
    _minutes = State(initialValue: initialMinutes(handoff))
    _note = State(initialValue: handoff?.bothSidesNote ?? "")
  }

  var body: some View {
    ScreenScaffold {
      ScreenTitle(handoff != nil ? "Finish feed" : "Log feed")
      if handoff != nil { Hint("Minutes filled from your timer — tweak anything before saving.") }
      LoggedAtField(value: $loggedAt)
      HStack(spacing: 8) {
        Pill(label: "Breast", selected: kind == .breast) { kind = .breast }
        Pill(label: "Bottle", selected: kind == .bottle) { kind = .bottle }
      }
      if kind == .breast {
        FieldLabel("Side")
        HStack(spacing: 8) {
          Pill(label: "Left", selected: side == .left) { side = .left }
          Pill(label: "Right", selected: side == .right) { side = .right }
          Pill(label: "Both", selected: side == .both) { side = .both }
        }
        FormField(label: "Minutes", text: $minutes, placeholder: "e.g. 12", keyboard: .numberPad)
      } else {
        FormField(label: "Amount (\(units.volumeSymbol))", text: $ml, placeholder: "e.g. 90", keyboard: units.volumeUnit == .milliliters ? .numberPad : .decimalPad)
        HStack(spacing: 8) {
          Pill(label: "Formula", selected: milk == .formula) { milk = .formula }
          Pill(label: "Expressed", selected: milk == .expressed) { milk = .expressed }
        }
      }
      FormField(label: "Note", text: $note, placeholder: "e.g. Dream feed")
      PrimaryButton(label: "Save feed") { await save() }
    }
    .formAlert($alert)
    .task { await baby.bind(API.babies.get(babyId), convex) }
  }

  private func save() async {
    let duration = minutes.isEmpty ? nil : number(minutes)
    do {
      let type = FreeAllowance.type(for: .feed(kind, side: side, minutes: duration, amountMl: number(ml), milk: milk))
      let saved = try await gate.save(type, babyId: babyId) {
        try await convex.mutation(API.events.logFeed(
          babyId: babyId,
          loggedAt: loggedAt,
          feedKind: kind,
          side: kind == .breast ? side : nil,
          durationMinutes: duration,
          amountMl: kind == .bottle ? (number(ml).map(units.millilitres(fromInput:)) ?? 0) : nil,
          milk: kind == .bottle ? milk : nil,
          note: trimmedOrNil(note)
        ))
      }
      guard saved != nil else { return }
      saveFeedback.logged(.feed, babyId: babyId)
      if let baby = baby.value {
        await Reminders.refreshFeed(baby: baby, lastFeedAt: loggedAt + (duration ?? 0) * minuteMs, quiet: false)
      }
      router.showHome(babyId)
    } catch {
      alert = FormAlert(title: "That didn’t save", message: UserMessage.from(error, fallback: String(localized: "Try again")))
    }
  }
}

/// Port of pump/manual.tsx.
struct PumpManualView: View {
  let babyId: BabyID
  let handoff: TimerSession.Handoff?

  @Environment(ConvexService.self) private var convex
  @Environment(SaveFeedback.self) private var saveFeedback
  @Environment(AppRouter.self) private var router
  @Environment(LogGate.self) private var gate
  @State private var loggedAt: EpochMs
  @State private var side: Side
  @State private var minutes: String
  @State private var ml = ""
  @State private var note: String
  @State private var alert: FormAlert?
  private let units = DisplayFormat.current

  init(babyId: BabyID, handoff: TimerSession.Handoff?) {
    self.babyId = babyId
    self.handoff = handoff
    _loggedAt = State(initialValue: handoff.map { LoggedAt.snapToMinute($0.startedAt) } ?? LoggedAt.nowSnapped())
    _side = State(initialValue: handoff?.side ?? .left)
    _minutes = State(initialValue: initialMinutes(handoff))
    _note = State(initialValue: handoff?.bothSidesNote ?? "")
  }

  var body: some View {
    ScreenScaffold {
      ScreenTitle(handoff != nil ? "Finish pump" : "Log pump")
      if handoff != nil { Hint("Minutes filled from your timer — add ml if you measured.") }
      LoggedAtField(value: $loggedAt)
      FieldLabel("Side")
      HStack(spacing: 8) {
        Pill(label: "Left", selected: side == .left) { side = .left }
        Pill(label: "Right", selected: side == .right) { side = .right }
        Pill(label: "Both", selected: side == .both) { side = .both }
      }
      FormField(label: "Minutes", text: $minutes, placeholder: "e.g. 15", keyboard: .numberPad)
      FormField(label: "Amount (\(units.volumeSymbol))", text: $ml, placeholder: "Optional", keyboard: units.volumeUnit == .milliliters ? .numberPad : .decimalPad)
      FormField(label: "Note", text: $note, placeholder: "e.g. Let-down slow")
      PrimaryButton(label: "Save pump") { await save() }
    }
    .formAlert($alert)
  }

  private func save() async {
    guard let duration = number(minutes), duration >= 1 else {
      return alert = FormAlert(title: "Enter how long you pumped")
    }
    do {
      let saved = try await gate.save(.pump, babyId: babyId) {
        try await convex.mutation(API.events.logPump(
          babyId: babyId,
          loggedAt: loggedAt,
          side: side,
          durationMinutes: duration,
          amountMl: ml.isEmpty ? nil : number(ml).map(units.millilitres(fromInput:)),
          note: trimmedOrNil(note)
        ))
      }
      guard saved != nil else { return }
      saveFeedback.logged(.pump, babyId: babyId)
      router.popToRoot()
    } catch {
      alert = FormAlert(title: "That didn’t save", message: UserMessage.from(error, fallback: String(localized: "Try again")))
    }
  }
}

/// Port of sleep/manual.tsx and tummy/manual.tsx.
struct DurationManualView: View {
  let babyId: BabyID
  let kind: TimerKind
  let handoff: TimerSession.Handoff?

  @Environment(ConvexService.self) private var convex
  @Environment(SaveFeedback.self) private var saveFeedback
  @Environment(AppRouter.self) private var router
  @Environment(LogGate.self) private var gate
  @State private var loggedAt: EpochMs
  @State private var minutes: String
  @State private var note = ""
  @State private var alert: FormAlert?

  init(babyId: BabyID, kind: TimerKind, handoff: TimerSession.Handoff?) {
    self.babyId = babyId
    self.kind = kind
    self.handoff = handoff
    _loggedAt = State(initialValue: handoff.map { LoggedAt.snapToMinute($0.startedAt) } ?? LoggedAt.nowSnapped())
    _minutes = State(initialValue: initialMinutes(handoff))
  }

  private var isSleep: Bool { kind == .sleep }
  private var quick: [Int] { isSleep ? [30, 45, 60, 90, 120, 180] : [3, 5, 10, 15, 20, 30] }

  private func quickLabel(_ m: Int) -> LocalizedStringKey {
    if !isSleep || m < 60 { return "\(m)m" }
    return m % 60 == 0 ? "\(m / 60)h" : "\(m / 60)h \(m % 60)m"
  }

  var body: some View {
    ScreenScaffold {
      ScreenTitle(isSleep ? "Sleep" : "Tummy time")
      LoggedAtField(value: $loggedAt, label: isSleep ? "Fell asleep" : "Started")
      FieldLabel("Duration")
      WrapLayout {
        ForEach(quick, id: \.self) { m in
          Pill(
            label: quickLabel(m),
            selected: number(minutes) == Double(m),
            tint: isSleep ? C.purpleSoft : C.skySoft,
            ink: isSleep ? C.purple : C.sky
          ) { minutes = String(m) }
        }
      }
      FormField(label: "Minutes", text: $minutes, placeholder: isSleep ? "e.g. 45" : "e.g. 10", keyboard: .numberPad)
      FormField(label: "Note", text: $note, placeholder: isSleep ? "e.g. Pram nap" : "e.g. On the play mat")
      PrimaryButton(label: isSleep ? "Save sleep" : "Save tummy time") { await save() }
    }
    .formAlert($alert)
  }

  private func save() async {
    guard let duration = number(minutes), duration >= 1 else {
      return alert = FormAlert(title: isSleep ? "Enter how long they slept" : "Enter how long tummy time lasted")
    }
    do {
      if isSleep {
        try await convex.mutation(API.events.logSleep(babyId: babyId, loggedAt: loggedAt, durationMinutes: duration, note: trimmedOrNil(note)))
      } else {
        let saved = try await gate.save(.tummy, babyId: babyId) {
          try await convex.mutation(API.events.logTummy(babyId: babyId, loggedAt: loggedAt, durationMinutes: duration, note: trimmedOrNil(note)))
        }
        guard saved != nil else { return }
      }
      saveFeedback.logged(isSleep ? .sleep : .tummy, babyId: babyId)
      router.showHome(babyId)
    } catch {
      alert = FormAlert(title: "That didn’t save", message: UserMessage.from(error, fallback: String(localized: "Try again")))
    }
  }
}
