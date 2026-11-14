#if canImport(FoundationModels)
import AppIntents
import Foundation
import FoundationModels
import ScrunchCore

/// "Log it in Scrunch: 120 ml formula about 20 minutes ago". Apple's on-device model turns
/// the sentence into one structured log, so nothing leaves the phone to parse it.
@available(iOS 26.0, *)
struct DescribeLogIntent: AppIntent {
  static let title: LocalizedStringResource = "Log from a description"
  static let description = IntentDescription("Describe a feed, nappy, sleep or medicine in your own words and Scrunch logs it, using Apple Intelligence on this iPhone.")

  @Parameter(title: "What happened?", requestValueDialog: "What would you like to log?") var text: String
  @Parameter(title: "Baby") var baby: BabyEntity?

  static var parameterSummary: some ParameterSummary { Summary("Log \(\.$text) for \(\.$baby)") }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard SystemLanguageModel.default.isAvailable else { throw DescribeLogError.unavailable }
    let ref = try baby.resolved()
    let session = LanguageModelSession(instructions: """
      You turn a UK parent's short note about their baby into exactly one log entry. \
      Wee means a wet nappy and poo means a dirty nappy. Only fill in numbers the parent said.
      """)
    let parsed = try await session.respond(to: text, generating: DescribedLog.self).content
    guard let log = parsed.entry else { throw DescribeLogError.notUnderstood }
    try await requestConfirmation(actionName: .add, dialog: "Log \(log.summary.lowercasedFirst) for \(ref.name)?")
    let loggedAt = LoggedAt.snapToMinute(Date().epochMs - Double(max(0, parsed.minutesAgo ?? 0)) * minuteMs)
    await QuickLogStore.record(PendingLog(babyId: ref.id, loggedAt: loggedAt, log: log))
    return .result(dialog: "Logged \(log.summary.lowercasedFirst) for \(ref.name).")
  }
}

@available(iOS 26.0, *)
enum DescribeLogError: Error, CustomLocalizedStringResourceConvertible {
  case unavailable, notUnderstood

  var localizedStringResource: LocalizedStringResource {
    switch self {
    case .unavailable: "Apple Intelligence isn't available on this iPhone. Try \"Log a wet nappy in Scrunch\" instead."
    case .notUnderstood: "Sorry, I couldn't tell what to log. Try \"Log a feed in Scrunch\"."
    }
  }
}

@available(iOS 26.0, *)
@Generable
struct DescribedLog {
  @Generable
  enum Kind {
    case wetNappy, dirtyNappy, wetAndDirtyNappy, breastFeed, bottleFeed, sleep, tummyTime, pump, medicine, unknown
  }

  @Guide(description: "What kind of entry this is")
  var kind: Kind
  @Guide(description: "Millilitres of milk, for a bottle feed or pump")
  var millilitres: Int?
  @Guide(description: "How long it lasted, in minutes")
  var minutes: Int?
  @Guide(description: "How many minutes ago it started; 0 if it is happening now")
  var minutesAgo: Int?
  @Guide(description: "The medicine's name, such as Calpol")
  var medicineName: String?
  @Guide(description: "true if the bottle was expressed breast milk rather than formula")
  var expressed: Bool?

  var entry: LogEntry? {
    let minutes = minutes.map(Double.init).flatMap { $0 > 0 ? $0 : nil }
    let ml = millilitres.map(Double.init).flatMap { $0 > 0 ? $0 : nil }
    switch kind {
    case .wetNappy: return .nappy(.wet)
    case .dirtyNappy: return .nappy(.dirty)
    case .wetAndDirtyNappy: return .nappy(.both)
    case .breastFeed: return .feed(.breast, side: nil, minutes: minutes, amountMl: nil, milk: nil)
    case .bottleFeed:
      guard let ml else { return nil }
      return .feed(.bottle, side: nil, minutes: nil, amountMl: ml, milk: expressed == true ? .expressed : .formula)
    case .sleep: return minutes.map { .sleep(minutes: $0) }
    case .tummyTime: return minutes.map { .tummy(minutes: $0) }
    case .pump: return minutes.map { .pump(.both, minutes: $0, amountMl: ml) }
    case .medicine:
      guard let name = medicineName?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return nil }
      return .medicine(title: name)
    case .unknown: return nil
    }
  }
}
#endif
