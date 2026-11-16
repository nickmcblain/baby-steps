import Foundation

/// The short line shown after a successful save. Names the baby when we know it.
public enum SaveCopy {
  /// "Logged Eliza's feed", or "Feed logged" without a name.
  public static func logged(_ kind: EventKind, babyName: String?) -> String {
    // Pumping is the parent's, not the baby's.
    if kind == .pump { return String(localized: "Pump logged", bundle: .module) }
    guard let name = firstName(babyName) else { return unnamed(kind) }
    switch kind {
    case .feed: return String(localized: "Logged \(name)'s feed", bundle: .module)
    case .nappy: return String(localized: "Logged \(name)'s nappy", bundle: .module)
    case .potty: return String(localized: "Logged \(name)'s potty trip", bundle: .module)
    case .sleep: return String(localized: "Logged \(name)'s sleep", bundle: .module)
    case .tummy: return String(localized: "Logged \(name)'s tummy time", bundle: .module)
    case .pump: return String(localized: "Pump logged", bundle: .module)
    case .medicine: return String(localized: "Logged \(name)'s medicine", bundle: .module)
    case .activity: return String(localized: "Logged \(name)'s activity", bundle: .module)
    case .custom: return String(localized: "Saved \(name)'s event", bundle: .module)
    case .weight: return String(localized: "Saved \(name)'s weight", bundle: .module)
    case .height: return String(localized: "Saved \(name)'s height", bundle: .module)
    }
  }

  static func unnamed(_ kind: EventKind) -> String {
    switch kind {
    case .feed: String(localized: "Feed logged", bundle: .module)
    case .nappy: String(localized: "Nappy logged", bundle: .module)
    case .potty: String(localized: "Potty trip logged", bundle: .module)
    case .sleep: String(localized: "Sleep logged", bundle: .module)
    case .tummy: String(localized: "Tummy time logged", bundle: .module)
    case .pump: String(localized: "Pump logged", bundle: .module)
    case .medicine: String(localized: "Medicine logged", bundle: .module)
    case .activity: String(localized: "Activity logged", bundle: .module)
    case .custom: String(localized: "Event saved", bundle: .module)
    case .weight: String(localized: "Weight saved", bundle: .module)
    case .height: String(localized: "Height saved", bundle: .module)
    }
  }

  /// First word only, so "Eliza Rose" reads as "Eliza's".
  static func firstName(_ name: String?) -> String? {
    let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard let first = trimmed.split(separator: " ").first else { return nil }
    return String(first)
  }

}

public extension Insights {
  /// Leave a margin so "all caught up" never sits next to a feed that's nearly due.
  internal static let caughtUpFeedMarginMs = 30 * minuteMs

  /// Nothing needs doing right now: a recent feed with the next one well off, and not
  /// awake longer than usual. Running timers are the caller's to check.
  static func allCaughtUp(_ input: InsightInput) -> Bool {
    let all = feeds(input.recentFeeds)
    guard let last = all.last, last.loggedAt <= input.now, input.now - last.loggedAt < staleFeedMs else { return false }
    let due = nextFeedDue(after: last, feeds: all, input: input).at
    guard due - input.now > caughtUpFeedMarginMs else { return false }
    if !input.asleep, let end = input.lastSleepEndMs, end <= input.now {
      let range = typicalAwake(dateOfBirth: input.baby.dateOfBirth, now: input.now)
      if input.now - end > range.highMin * minuteMs { return false }
    }
    return true
  }
}

/// Little firsts a parent can tick off whenever they happen. No target ages on purpose:
/// every baby has their own pace, and the app never prompts for these.
public enum Milestone: String, CaseIterable, Identifiable, Sendable, ConvexRepresentable {
  case firstSmile, firstLaugh, rolledOver, satUp, firstTooth, firstFood, crawled, firstSteps

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .firstSmile: String(localized: "First smile", bundle: .module)
    case .firstLaugh: String(localized: "First laugh", bundle: .module)
    case .rolledOver: String(localized: "Rolled over", bundle: .module)
    case .satUp: String(localized: "Sat up", bundle: .module)
    case .firstTooth: String(localized: "First tooth", bundle: .module)
    case .firstFood: String(localized: "First taste of food", bundle: .module)
    case .crawled: String(localized: "First crawl", bundle: .module)
    case .firstSteps: String(localized: "First steps", bundle: .module)
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
    guard let name = SaveCopy.firstName(babyName) else {
      return String(localized: "\(milestone.title) saved", bundle: .module, comment: "Toast after ticking a milestone, e.g. First smile saved")
    }
    switch milestone {
    case .firstSmile: return String(localized: "Saved \(name)'s first smile", bundle: .module)
    case .firstLaugh: return String(localized: "Saved \(name)'s first laugh", bundle: .module)
    case .rolledOver: return String(localized: "Saved: \(name) rolled over", bundle: .module)
    case .satUp: return String(localized: "Saved: \(name) sat up", bundle: .module)
    case .firstTooth: return String(localized: "Saved \(name)'s first tooth", bundle: .module)
    case .firstFood: return String(localized: "Saved \(name)'s first taste of food", bundle: .module)
    case .crawled: return String(localized: "Saved \(name)'s first crawl", bundle: .module)
    case .firstSteps: return String(localized: "Saved \(name)'s first steps", bundle: .module)
    }
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
