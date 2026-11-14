import AppIntents
import Foundation
import ScrunchCore

// App Intents for every log type, shared by Siri, Shortcuts, the interactive widgets, the
// Live Activity and Control Centre. Log intents only queue (see QuickLogStore); timer
// intents are LiveActivityIntents, so the system always runs them in the app's process.

// MARK: - Baby

struct BabyEntity: AppEntity {
  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Baby"
  static let defaultQuery = BabyQuery()

  var id: BabyID
  var name: String

  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

  init(_ ref: SharedBabies.Ref) {
    id = ref.id
    name = ref.name
  }
}

struct BabyQuery: EntityQuery {
  func entities(for identifiers: [BabyEntity.ID]) async throws -> [BabyEntity] {
    QuickLogStore.babies.babies.filter { identifiers.contains($0.id) }.map(BabyEntity.init)
  }

  func suggestedEntities() async throws -> [BabyEntity] {
    QuickLogStore.babies.babies.map(BabyEntity.init)
  }

  func defaultResult() async -> BabyEntity? {
    QuickLogStore.babies.active.map(BabyEntity.init)
  }
}

enum ScrunchIntentError: Error, CustomLocalizedStringResourceConvertible {
  case noBaby
  case otherTimerRunning(String)
  case freeLimit(LogType?)

  var localizedStringResource: LocalizedStringResource {
    switch self {
    case .noBaby: "Open Scrunch and add a baby first, then try again."
    case .otherTimerRunning(let timer): "A \(timer) timer is already running. Stop it first."
    case .freeLimit(let type):
      "\(FreeAllowance.paywallTitle(type)), so I've kept this one. Open Scrunch to subscribe and it will be saved."
    }
  }
}

extension BabyEntity? {
  func resolved() throws -> SharedBabies.Ref {
    if let self { return SharedBabies.Ref(id: self.id, name: self.name) }
    guard let active = QuickLogStore.babies.active else { throw ScrunchIntentError.noBaby }
    return active
  }
}

/// Queue a log for the baby and build the Siri reply.
@MainActor
private func logNow(
  _ log: LogEntry, baby: BabyEntity?, minutesAgo: Double = 0, note: String? = nil, from intent: any AppIntent
) async throws -> IntentDialog {
  let ref = try baby.resolved()
  let loggedAt = LoggedAt.snapToMinute(Date().epochMs - minutesAgo * minuteMs)
  let outcome = await QuickLogStore.record(PendingLog(babyId: ref.id, loggedAt: loggedAt, log: log, note: note))
  if case .held(let type) = outcome { throw freeLimitReached(type, from: intent) }
  return "Logged \(log.summary.lowercasedFirst) for \(ref.name)."
}

/// Past the free allowance the log is held, and Siri opens Scrunch to the paywall. Widget buttons
/// can't open the app from here, so the widget redraws with buttons that do (see QuickLogWidget).
@MainActor
func freeLimitReached(_ type: LogType?, from intent: any AppIntent) -> Error {
  #if !WIDGET_EXTENSION
  if let intent = intent as? any ForegroundContinuableIntent {
    let dialog: IntentDialog = "\(FreeAllowance.paywallTitle(type)), so I've kept this one. Subscribe in Scrunch and it will be saved."
    return intent.needsToContinueInForegroundError(dialog)
  }
  #endif
  return ScrunchIntentError.freeLimit(type)
}

/// Opens Scrunch to the paywall. Widget buttons switch to this once the free entries are used.
struct OpenPaywallIntent: AppIntent {
  static let title: LocalizedStringResource = "Subscribe to Scrunch"
  static let isDiscoverable = false
  static let openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    GlanceStore.defaults.set(true, forKey: openPaywallKey)
    return .result()
  }
}

let openPaywallKey = "open-paywall"

#if !WIDGET_EXTENSION
extension LogNappyIntent: ForegroundContinuableIntent {}
extension LogPottyIntent: ForegroundContinuableIntent {}
extension LogFeedIntent: ForegroundContinuableIntent {}
extension LogTummyIntent: ForegroundContinuableIntent {}
extension LogPumpIntent: ForegroundContinuableIntent {}
extension LogWeightIntent: ForegroundContinuableIntent {}
extension LogHeightIntent: ForegroundContinuableIntent {}
extension LogMedicineIntent: ForegroundContinuableIntent {}
extension LogActivityIntent: ForegroundContinuableIntent {}
extension LogCustomIntent: ForegroundContinuableIntent {}
#endif

extension String {
  var lowercasedFirst: String { prefix(1).lowercased() + dropFirst() }

  var trimmedOrNil: String? {
    let value = trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }
}

// MARK: - Options

enum NappyOption: String, AppEnum {
  case wet, dirty, both

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Nappy"
  static let caseDisplayRepresentations: [NappyOption: DisplayRepresentation] = [
    .wet: DisplayRepresentation(title: "wet", synonyms: ["wee", "weeing"]),
    .dirty: DisplayRepresentation(title: "dirty", synonyms: ["poo", "pooey", "poopy"]),
    .both: DisplayRepresentation(title: "wet and dirty", synonyms: ["mixed", "wee and poo"]),
  ]

  var nappy: QuickLog.Nappy {
    switch self {
    case .wet: .wet
    case .dirty: .dirty
    case .both: .both
    }
  }
}

enum FeedOption: String, AppEnum {
  case breast, bottle

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Feed"
  static let caseDisplayRepresentations: [FeedOption: DisplayRepresentation] = [
    .breast: DisplayRepresentation(title: "breast", synonyms: ["breastfeed", "nursing"]),
    .bottle: DisplayRepresentation(title: "bottle", synonyms: ["formula"]),
  ]

  var kind: FeedKind { self == .breast ? .breast : .bottle }
}

enum SideOption: String, AppEnum {
  case left, right, both

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Side"
  static let caseDisplayRepresentations: [SideOption: DisplayRepresentation] = [
    .left: "Left", .right: "Right", .both: "Both",
  ]

  var side: Side {
    switch self {
    case .left: .left
    case .right: .right
    case .both: .both
    }
  }
}

enum MilkOption: String, AppEnum {
  case formula, expressed

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Milk"
  static let caseDisplayRepresentations: [MilkOption: DisplayRepresentation] = [
    .formula: "Formula", .expressed: "Expressed",
  ]

  var milk: Milk { self == .formula ? .formula : .expressed }
}

enum TimerOption: String, AppEnum {
  case feed, nap, tummy, pump

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Timer"
  static let caseDisplayRepresentations: [TimerOption: DisplayRepresentation] = [
    .feed: DisplayRepresentation(title: "feed", synonyms: ["breastfeed"]),
    .nap: DisplayRepresentation(title: "nap", synonyms: ["sleep"]),
    .tummy: DisplayRepresentation(title: "tummy time", synonyms: ["tummy"]),
    .pump: DisplayRepresentation(title: "pump", synonyms: ["pumping", "expressing"]),
  ]

  init(_ kind: TimerKind) {
    switch kind {
    case .feed: self = .feed
    case .sleep: self = .nap
    case .tummy: self = .tummy
    case .pump: self = .pump
    }
  }

  var kind: TimerKind {
    switch self {
    case .feed: .feed
    case .nap: .sleep
    case .tummy: .tummy
    case .pump: .pump
    }
  }

  var spoken: String { self == .tummy ? "tummy time" : rawValue }
}

// MARK: - Log intents

struct LogNappyIntent: AppIntent {
  static let title: LocalizedStringResource = "Log a nappy"
  static let description = IntentDescription("Logs a wet, dirty or wet and dirty nappy.")

  @Parameter(title: "Nappy", default: .wet) var nappy: NappyOption
  @Parameter(title: "Baby") var baby: BabyEntity?

  static var parameterSummary: some ParameterSummary { Summary("Log a \(\.$nappy) nappy for \(\.$baby)") }

  init() {}
  init(nappy: NappyOption) { self.nappy = nappy }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    .result(dialog: try await logNow(.nappy(nappy.nappy), baby: baby, from: self))
  }
}

struct LogPottyIntent: AppIntent {
  static let title: LocalizedStringResource = "Log a potty visit"
  static let description = IntentDescription("Logs a wee, poo or both on the potty.")

  @Parameter(title: "What", default: .wet) var nappy: NappyOption
  @Parameter(title: "Baby") var baby: BabyEntity?

  static var parameterSummary: some ParameterSummary { Summary("Log a \(\.$nappy) potty visit for \(\.$baby)") }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    .result(dialog: try await logNow(.potty(nappy.nappy), baby: baby, from: self))
  }
}

struct LogFeedIntent: AppIntent {
  static let title: LocalizedStringResource = "Log a feed"
  static let description = IntentDescription("Logs a breast or bottle feed that has already happened.")

  @Parameter(title: "Feed", default: .bottle) var feed: FeedOption
  @Parameter(title: "Amount (ml)", inclusiveRange: (1, 500)) var amountMl: Int?
  @Parameter(title: "Milk", default: .formula) var milk: MilkOption
  @Parameter(title: "Side") var side: SideOption?
  @Parameter(title: "Minutes", inclusiveRange: (1, 180)) var minutes: Int?
  @Parameter(title: "Baby") var baby: BabyEntity?

  static var parameterSummary: some ParameterSummary {
    Summary("Log a \(\.$feed) feed for \(\.$baby)") {
      \.$amountMl
      \.$milk
      \.$side
      \.$minutes
    }
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    if feed == .bottle, amountMl == nil {
      throw $amountMl.needsValueError("How much did they have, in ml?")
    }
    let log = LogEntry.feed(
      feed.kind,
      side: side?.side,
      minutes: minutes.map(Double.init),
      amountMl: amountMl.map(Double.init),
      milk: milk.milk
    )
    return .result(dialog: try await logNow(log, baby: baby, minutesAgo: Double(minutes ?? 0), from: self))
  }
}

struct LogSleepIntent: AppIntent {
  static let title: LocalizedStringResource = "Log a sleep"
  static let description = IntentDescription("Logs a nap or sleep that has just ended.")

  @Parameter(title: "Minutes", inclusiveRange: (1, 720)) var minutes: Int
  @Parameter(title: "Baby") var baby: BabyEntity?

  static var parameterSummary: some ParameterSummary { Summary("Log a \(\.$minutes) minute sleep for \(\.$baby)") }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    .result(dialog: try await logNow(.sleep(minutes: Double(minutes)), baby: baby, minutesAgo: Double(minutes), from: self))
  }
}

struct LogTummyIntent: AppIntent {
  static let title: LocalizedStringResource = "Log tummy time"
  static let description = IntentDescription("Logs tummy time that has just ended.")

  @Parameter(title: "Minutes", inclusiveRange: (1, 120)) var minutes: Int
  @Parameter(title: "Baby") var baby: BabyEntity?

  static var parameterSummary: some ParameterSummary { Summary("Log \(\.$minutes) minutes of tummy time for \(\.$baby)") }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    .result(dialog: try await logNow(.tummy(minutes: Double(minutes)), baby: baby, minutesAgo: Double(minutes), from: self))
  }
}

struct LogPumpIntent: AppIntent {
  static let title: LocalizedStringResource = "Log a pump"
  static let description = IntentDescription("Logs an expressing session that has just ended.")

  @Parameter(title: "Minutes", inclusiveRange: (1, 120)) var minutes: Int
  @Parameter(title: "Side", default: .both) var side: SideOption
  @Parameter(title: "Amount (ml)", inclusiveRange: (1, 500)) var amountMl: Int?
  @Parameter(title: "Baby") var baby: BabyEntity?

  static var parameterSummary: some ParameterSummary {
    Summary("Log a \(\.$minutes) minute pump for \(\.$baby)") {
      \.$side
      \.$amountMl
    }
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let log = LogEntry.pump(side.side, minutes: Double(minutes), amountMl: amountMl.map(Double.init))
    return .result(dialog: try await logNow(log, baby: baby, minutesAgo: Double(minutes), from: self))
  }
}

struct LogWeightIntent: AppIntent {
  static let title: LocalizedStringResource = "Log a weight"
  static let description = IntentDescription("Logs a weigh-in, in kilograms or pounds.")

  @Parameter(title: "Weight", defaultUnit: .kilograms) var weight: Measurement<UnitMass>
  @Parameter(title: "Baby") var baby: BabyEntity?

  static var parameterSummary: some ParameterSummary { Summary("Log a weight of \(\.$weight) for \(\.$baby)") }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let grams = weight.converted(to: .grams).value.rounded()
    return .result(dialog: try await logNow(.weight(grams: grams), baby: baby, from: self))
  }
}

struct LogHeightIntent: AppIntent {
  static let title: LocalizedStringResource = "Log a length"
  static let description = IntentDescription("Logs a length or height measurement.")

  @Parameter(title: "Length", defaultUnit: .centimeters) var length: Measurement<UnitLength>
  @Parameter(title: "Baby") var baby: BabyEntity?

  static var parameterSummary: some ParameterSummary { Summary("Log a length of \(\.$length) for \(\.$baby)") }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let cm = (length.converted(to: .centimeters).value * 10).rounded() / 10
    return .result(dialog: try await logNow(.height(cm: cm), baby: baby, from: self))
  }
}

struct LogMedicineIntent: AppIntent {
  static let title: LocalizedStringResource = "Log a medicine"
  static let description = IntentDescription("Logs a medicine dose, such as Calpol.")

  @Parameter(title: "Medicine") var name: String
  @Parameter(title: "Dose") var dose: String?
  @Parameter(title: "Baby") var baby: BabyEntity?

  static var parameterSummary: some ParameterSummary { Summary("Log \(\.$name) for \(\.$baby)") { \.$dose } }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard let title = name.trimmedOrNil else { throw $name.needsValueError("Which medicine?") }
    return .result(dialog: try await logNow(.medicine(title: title), baby: baby, note: dose?.trimmedOrNil, from: self))
  }
}

struct LogActivityIntent: AppIntent {
  static let title: LocalizedStringResource = "Log an activity"
  static let description = IntentDescription("Logs an activity, such as a bath or a walk.")

  @Parameter(title: "Activity") var name: String
  @Parameter(title: "Minutes", inclusiveRange: (1, 600)) var minutes: Int?
  @Parameter(title: "Baby") var baby: BabyEntity?

  static var parameterSummary: some ParameterSummary { Summary("Log \(\.$name) for \(\.$baby)") { \.$minutes } }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard let title = name.trimmedOrNil else { throw $name.needsValueError("What did you do?") }
    return .result(dialog: try await logNow(.activity(title: title, minutes: minutes.map(Double.init)), baby: baby, from: self))
  }
}

struct LogCustomIntent: AppIntent {
  static let title: LocalizedStringResource = "Log a moment"
  static let description = IntentDescription("Logs anything else, with an optional note.")

  @Parameter(title: "Title") var name: String
  @Parameter(title: "Note") var note: String?
  @Parameter(title: "Baby") var baby: BabyEntity?

  static var parameterSummary: some ParameterSummary { Summary("Log \(\.$name) for \(\.$baby)") { \.$note } }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard let title = name.trimmedOrNil else { throw $name.needsValueError("What would you like to log?") }
    return .result(dialog: try await logNow(.custom(title: title), baby: baby, note: note?.trimmedOrNil, from: self))
  }
}

// MARK: - Timers

struct StartTimerIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Start a timer"
  static let description = IntentDescription("Starts a feed, nap, tummy time or pump timer on the Lock Screen and Dynamic Island.")

  @Parameter(title: "Timer", default: .feed) var timer: TimerOption
  @Parameter(title: "Baby") var baby: BabyEntity?

  static var parameterSummary: some ParameterSummary { Summary("Start a \(\.$timer) timer for \(\.$baby)") }

  init() {}
  init(timer: TimerOption) { self.timer = timer }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    #if WIDGET_EXTENSION
    return .result(dialog: "Open Scrunch to do that.")
    #else
    let ref = try baby.resolved()
    let kind = timer.kind
    let store = TimerStore.shared
    if let running = store.session {
      if running.kind == kind, running.babyId == ref.id, running.isRunning {
        return .result(dialog: "The \(timer.spoken) timer is already running for \(ref.name).")
      }
      throw ScrunchIntentError.otherTimerRunning(TimerOption(running.kind).spoken)
    }
    await store.update(.started(kind: kind, babyId: ref.id, babyName: ref.name, now: Date().epochMs))
    return .result(dialog: "Started a \(timer.spoken) timer for \(ref.name).")
    #endif
  }
}

struct StopTimerIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Stop the timer"
  static let description = IntentDescription("Stops the running timer and saves it.")

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    #if WIDGET_EXTENSION
    return .result(dialog: "Open Scrunch to do that.")
    #else
    let store = TimerStore.shared
    guard var session = store.session else { return .result(dialog: "No timer is running.") }
    session.pause(now: Date().epochMs)
    let name = session.babyName ?? "your baby"
    await store.stop()
    guard let log = session.finishedLog() else {
      return .result(dialog: "That was under five seconds, so nothing was saved.")
    }
    if case .held(let type) = await QuickLogStore.record(log) {
      return .result(dialog: "\(FreeAllowance.paywallTitle(type)), so this one is kept until you subscribe in Scrunch.")
    }
    return .result(dialog: "Saved \(log.log.summary.lowercasedFirst) for \(name).")
    #endif
  }
}
