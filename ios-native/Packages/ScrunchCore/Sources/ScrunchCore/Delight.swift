import Foundation

/// The short line shown after a successful save. Names the baby when we know it.
public enum SaveCopy {
  /// "Logged Eliza's feed", or "Feed logged" without a name.
  public static func logged(_ kind: EventKind, babyName: String?) -> String {
    // Pumping is the parent's, not the baby's.
    if kind == .pump { return "Pump logged" }
    let noun = noun(kind)
    let verb = kind == .weight || kind == .height || kind == .custom ? "Saved" : "Logged"
    guard let name = firstName(babyName) else {
      return "\(EventCopy.capitalize(noun)) \(verb.lowercased())"
    }
    return "\(verb) \(possessive(name)) \(noun)"
  }

  static func noun(_ kind: EventKind) -> String {
    switch kind {
    case .feed: "feed"
    case .nappy: "nappy"
    case .potty: "potty trip"
    case .sleep: "sleep"
    case .tummy: "tummy time"
    case .pump: "pump"
    case .medicine: "medicine"
    case .activity: "activity"
    case .custom: "event"
    case .weight: "weight"
    case .height: "height"
    }
  }

  /// First word only, so "Eliza Rose" reads as "Eliza's".
  static func firstName(_ name: String?) -> String? {
    let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard let first = trimmed.split(separator: " ").first else { return nil }
    return String(first)
  }

  /// UK style: "James's", "Eliza's".
  static func possessive(_ name: String) -> String { "\(name)'s" }
}

/// Home's quiet "all caught up" moment: fed recently, no nap due, no timer to stop.
public struct CaughtUp: Equatable, Sendable {
  public let nextFeedAt: EpochMs

  /// Leave a margin so the card never sits next to a feed that's nearly due.
  static let feedMarginMs = 30 * minuteMs
  static let napMarginMs = 15 * minuteMs

  public static func state(
    lastFeedEndedAt: EpochMs?,
    window: FeedWindow?,
    napAt: EpochMs?,
    timerRunning: Bool,
    now: EpochMs
  ) -> CaughtUp? {
    guard !timerRunning, let lastFeedEndedAt, let window, lastFeedEndedAt <= now else { return nil }
    let nextFeedAt = FeedWindows.nextFeedDueAt(lastFeedAt: lastFeedEndedAt, window: window)
    guard nextFeedAt - now > feedMarginMs else { return nil }
    if let napAt, napAt - now <= napMarginMs { return nil }
    return CaughtUp(nextFeedAt: nextFeedAt)
  }

  public func detail(calendar: Calendar = .current) -> String {
    "Next feed around \(Clock.h12(nextFeedAt, calendar: calendar)). Rest if you can."
  }
}

/// Little firsts a parent can tick off whenever they happen. No target ages on purpose:
/// every baby has their own pace, and the app never prompts for these.
public enum Milestone: String, CaseIterable, Identifiable, Sendable, ConvexRepresentable {
  case firstSmile, firstLaugh, rolledOver, satUp, firstTooth, firstFood, crawled, firstSteps

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .firstSmile: "First smile"
    case .firstLaugh: "First laugh"
    case .rolledOver: "Rolled over"
    case .satUp: "Sat up"
    case .firstTooth: "First tooth"
    case .firstFood: "First taste of food"
    case .crawled: "First crawl"
    case .firstSteps: "First steps"
    }
  }
}

/// A ticked milestone. `key` stays a string so a key this build doesn't know is skipped, not fatal.
public struct MilestoneMark: Decodable, Equatable, Hashable, Sendable {
  public let key: String
  public let reachedAt: EpochMs

  public init(_ milestone: Milestone, reachedAt: EpochMs) {
    key = milestone.rawValue
    self.reachedAt = reachedAt
  }

  public var milestone: Milestone? { Milestone(rawValue: key) }
}

public enum MilestoneCopy {
  /// "Saved Eliza's first smile", or "First smile saved" without a name.
  public static func saved(_ milestone: Milestone, babyName: String?) -> String {
    let title = milestone.title
    guard let name = SaveCopy.firstName(babyName) else { return "\(title) saved" }
    return "Saved \(SaveCopy.possessive(name)) \(title.prefix(1).lowercased() + title.dropFirst())"
  }

  /// Every milestone in catalogue order, with the date it was reached if it has been.
  public static func rows(_ marks: [MilestoneMark]) -> [(milestone: Milestone, reachedAt: EpochMs?)] {
    var reached: [Milestone: EpochMs] = [:]
    for mark in marks {
      guard let milestone = mark.milestone else { continue }
      reached[milestone] = reached[milestone].map { min($0, mark.reachedAt) } ?? mark.reachedAt
    }
    return Milestone.allCases.map { ($0, reached[$0]) }
  }
}
