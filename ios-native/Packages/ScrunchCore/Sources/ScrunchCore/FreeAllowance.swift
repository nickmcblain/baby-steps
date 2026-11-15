import Foundation

/// What each free allowance counts. Sleep has none: it is always free.
public enum LogType: String, Codable, CaseIterable, Sendable {
  case feed, nappy, pump, growth, tummy, potty, medicine, activity, note

  /// "feeds", as in "3 of 10 free feeds left".
  public var plural: String {
    switch self {
    case .feed: "feeds"
    case .nappy: "nappies"
    case .pump: "pumping sessions"
    case .growth: "growth entries"
    case .tummy: "tummy times"
    case .potty: "potty trips"
    case .medicine: "medicine doses"
    case .activity: "activities"
    case .note: "notes"
    }
  }
}

/// The usage-based trial: each carer gets `limit` entries of each log type except sleep on each
/// baby, then logging that type needs their own subscription.
/// Convex enforces the same rule in convex/lib/allowance.ts.
public enum FreeAllowance {
  /// Resources/free-allowance.json is the one place the numbers live; convex/lib/allowance.ts
  /// imports the same file.
  private struct Config: Decodable {
    let freeLimit: Int
    let hintWhenRemaining: Int
  }

  private static let config: Config = {
    guard let url = Bundle.module.url(forResource: "free-allowance", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let config = try? JSONDecoder().decode(Config.self, from: data)
    else { fatalError("ScrunchCore is missing Resources/free-allowance.json") }
    return config
  }()

  public static let limit = config.freeLimit
  /// The hint shows once this many or fewer free entries of a type are left.
  public static let hintWhenRemaining = config.hintWhenRemaining

  public static func type(for entry: LogEntry) -> LogType? {
    switch entry {
    case .feed: .feed
    case .nappy: .nappy
    case .potty: .potty
    case .sleep: nil
    case .tummy: .tummy
    case .pump: .pump
    case .weight, .height: .growth
    case .medicine: .medicine
    case .activity: .activity
    case .custom: .note
    }
  }

  public static func canLog(_ type: LogType?, used: Int, unlocked: Bool) -> Bool {
    type == nil || unlocked || used < limit
  }

  public static func remaining(used: Int) -> Int { max(0, limit - used) }

  /// Ask and patterns stay open until the first free allowance runs out.
  public static func trialUsed(_ used: [LogType: Int]) -> Bool {
    used.values.contains { $0 >= limit }
  }

  /// The one gentle heads-up per type, once `hintWhenRemaining` or fewer free entries are left.
  public static func hint(_ type: LogType, used: Int) -> String? {
    let left = remaining(used: used)
    guard (1...hintWhenRemaining).contains(left) else { return nil }
    return String(
      localized: "allowance.hint",
      defaultValue: "\(left) of \(limit) free \(type.plural) left. Sleep is always free.",
      comment: "Toast once a few free entries of a type are left"
    )
  }

  public static func paywallTitle(_ type: LogType?) -> String {
    guard let type else { return "Keep logging with Scrunch" }
    return String(
      localized: "allowance.paywall.title",
      defaultValue: "You've used your \(limit) free \(type.plural)",
      comment: "Paywall title after the free entries of a type are used"
    )
  }
}

/// This carer's allowance on one baby, as Convex reports it. `unlocked` is the carer's own
/// subscription: a partner's doesn't count.
public struct BabyAllowance: Codable, Equatable, Sendable {
  public var babyId: BabyID
  public var unlocked: Bool
  public var used: [LogType: Int]

  public init(babyId: BabyID, unlocked: Bool, used: [LogType: Int]) {
    self.babyId = babyId
    self.unlocked = unlocked
    self.used = used
  }

  public func used(_ type: LogType) -> Int { used[type] ?? 0 }

  public func canLog(_ entry: LogEntry, subscribed: Bool) -> Bool {
    let type = FreeAllowance.type(for: entry)
    return FreeAllowance.canLog(type, used: type.map { used($0) } ?? 0, unlocked: unlocked || subscribed)
  }

  public var trialUsed: Bool { FreeAllowance.trialUsed(used) }
}

/// `allowance:mine`. Types the app doesn't know yet are skipped.
public struct AllowanceResponse: Decodable, Equatable, Sendable {
  public let babies: [BabyAllowance]

  private struct Baby: Decodable {
    struct Used: Decodable { let type: String; let used: Double }
    let babyId: BabyID
    let unlocked: Bool
    let used: [Used]
  }

  private enum CodingKeys: String, CodingKey { case babies }

  public init(from decoder: Decoder) throws {
    let raw = try decoder.container(keyedBy: CodingKeys.self).decode([Baby].self, forKey: .babies)
    babies = raw.map { baby in
      var used: [LogType: Int] = [:]
      for entry in baby.used {
        if let type = LogType(rawValue: entry.type) { used[type] = Int(entry.used) }
      }
      return BabyAllowance(babyId: baby.babyId, unlocked: baby.unlocked, used: used)
    }
  }
}

/// The allowance mirrored into the app group, so Siri, widgets and controls apply the same rule
/// without a Convex connection. `subscribed` is what StoreKit says on this device.
public struct SharedAllowance: Codable, Equatable, Sendable {
  public static let storageKey = "shared-allowance-v1"

  public var babies: [BabyID: BabyAllowance]
  public var subscribed: Bool

  public init(babies: [BabyID: BabyAllowance] = [:], subscribed: Bool = false) {
    self.babies = babies
    self.subscribed = subscribed
  }

  /// Unknown babies are allowed: Convex still has the final say when the log is sent.
  public func canLog(_ entry: LogEntry, babyId: BabyID) -> Bool {
    guard let baby = babies[babyId] else { return true }
    return baby.canLog(entry, subscribed: subscribed)
  }

  /// After a log is queued, so the next one from a widget sees it.
  public func counting(_ entry: LogEntry, babyId: BabyID) -> SharedAllowance {
    guard let type = FreeAllowance.type(for: entry), var baby = babies[babyId] else { return self }
    baby.used[type, default: 0] += 1
    var copy = self
    copy.babies[babyId] = baby
    return copy
  }

  public static func load(from defaults: UserDefaults) -> SharedAllowance {
    guard let data = defaults.data(forKey: storageKey),
          let value = try? JSONDecoder().decode(SharedAllowance.self, from: data) else {
      return SharedAllowance()
    }
    return value
  }

  public func save(to defaults: UserDefaults) {
    if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.storageKey) }
  }
}

/// Convex's structured refusals, from the JSON in `ClientError.ConvexError(data:)`.
public enum ServerRefusal: Error, Equatable, Sendable {
  case freeLimit(LogType?)
  case subscriptionRequired
  case sharingNeedsSubscription

  public init?(errorData: String) {
    struct Payload: Decodable { let code: String; let type: String?; let feature: String? }
    guard let payload = try? JSONDecoder().decode(Payload.self, from: Data(errorData.utf8)) else { return nil }
    switch payload.code {
    case "FREE_LIMIT_REACHED": self = .freeLimit(payload.type.flatMap(LogType.init(rawValue:)))
    case "SUBSCRIPTION_REQUIRED": self = payload.feature == "sharing" ? .sharingNeedsSubscription : .subscriptionRequired
    default: return nil
    }
  }

  public var message: String {
    switch self {
    case .freeLimit(let type): "\(FreeAllowance.paywallTitle(type)). Subscribe to keep logging them; sleep is always free."
    case .subscriptionRequired: "You've used your free entries. Subscribe to keep using Ask."
    case .sharingNeedsSubscription: "Each carer needs their own Scrunch subscription to share a baby."
    }
  }
}
