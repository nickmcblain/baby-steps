import Foundation

// Plain-words "right now" insights for Home. Estimates only — cues come first; not medical advice.

public struct Insight: Equatable, Sendable {
  public enum Kind: String, Sendable {
    case nextFeed, lastNappy, breastSide, awake, tonightTog
  }

  public var kind: Kind
  /// One short line, e.g. "Next feed likely around 2:40 pm".
  public var headline: String
  /// Where it comes from, or what to do when data is thin.
  public var detail: String

  public init(kind: Kind, headline: String, detail: String) {
    self.kind = kind
    self.headline = headline
    self.detail = detail
  }
}

public struct InsightInput: Sendable {
  public var baby: Baby
  public var now: EpochMs
  /// Any recent events; non-feeds are ignored. Order and duplicates don't matter.
  public var recentFeeds: [Event]
  public var lastNappy: Event?
  public var lastSleepEndMs: EpochMs?
  public var asleep: Bool

  public init(
    baby: Baby,
    now: EpochMs,
    recentFeeds: [Event],
    lastNappy: Event?,
    lastSleepEndMs: EpochMs?,
    asleep: Bool
  ) {
    self.baby = baby
    self.now = now
    self.recentFeeds = recentFeeds
    self.lastNappy = lastNappy
    self.lastSleepEndMs = lastSleepEndMs
    self.asleep = asleep
  }
}

public struct WakeRange: Equatable, Sendable {
  public var lowMin: Double
  public var highMin: Double
}

public enum Insights {
  /// Feeds needed (gaps = feeds − 1) before we trust the baby's own rhythm over age norms.
  static let minGapsForPersonal = 3
  /// Start-to-start gaps outside this band are treated as split logs or missed logs.
  static let minGapMs = 45 * minuteMs
  static let maxGapMs = 6 * hourMs
  static let personalLookbackMs = 24 * hourMs
  /// Past this, the last log probably isn't the last feed — say so rather than guess.
  static let staleFeedMs = 8 * hourMs
  static let staleNappyMs = 24 * hourMs
  static let staleAwakeMs = 6 * hourMs
  static let breastSideMaxAgeMs = 12 * hourMs

  public static func all(_ input: InsightInput, calendar: Calendar = .current) -> [Insight] {
    [
      nextFeed(input, calendar: calendar),
      breastSide(input),
      lastNappy(input, calendar: calendar),
      awake(input),
      tonightTog(input),
    ].compactMap { $0 }
  }

  static func feeds(_ events: [Event]) -> [Event] {
    var seen = Set<EventID>()
    return events
      .filter { $0.kind == .feed && seen.insert($0.id).inserted }
      .sorted { $0.loggedAt < $1.loggedAt }
  }

  /// Median start-to-start gap over the last 24h, or nil when there aren't enough feeds.
  static func personalGapMs(_ feeds: [Event], now: EpochMs) -> (gapMs: Double, count: Int)? {
    let recent = feeds.filter { now - $0.loggedAt <= personalLookbackMs && $0.loggedAt <= now }
    var gaps: [Double] = []
    for (previous, next) in zip(recent, recent.dropFirst()) {
      let gap = next.loggedAt - previous.loggedAt
      if gap >= minGapMs && gap <= maxGapMs { gaps.append(gap) }
    }
    guard gaps.count >= minGapsForPersonal else { return nil }
    gaps.sort()
    let mid = gaps.count / 2
    let median = gaps.count % 2 == 0 ? (gaps[mid - 1] + gaps[mid]) / 2 : gaps[mid]
    return (median, gaps.count + 1)
  }

  public static func nextFeed(_ input: InsightInput, calendar: Calendar = .current) -> Insight? {
    let all = feeds(input.recentFeeds)
    guard let last = all.last else {
      return Insight(
        kind: .nextFeed,
        headline: "Log a feed to see when the next is likely",
        detail: "We'll start with typical gaps for \(input.baby.name)'s age."
      )
    }
    let since = max(0, input.now - last.loggedAt)
    let sinceText = "Last feed \(span(since)) ago"
    if since >= staleFeedMs {
      return Insight(
        kind: .nextFeed,
        headline: "No feed logged for \(span(since))",
        detail: "Log feeds as they happen and the estimate comes back."
      )
    }

    let (due, source) = nextFeedDue(after: last, feeds: all, input: input)
    if due <= input.now {
      return Insight(
        kind: .nextFeed,
        headline: "Feed may be due now",
        detail: "\(sinceText) · watch for hunger cues"
      )
    }
    return Insight(
      kind: .nextFeed,
      headline: "Next feed likely around \(Clock.h12(due, calendar: calendar))",
      detail: "\(sinceText) · \(source)"
    )
  }

  /// The likely next feed time and where the gap comes from.
  static func nextFeedDue(after last: Event, feeds all: [Event], input: InsightInput) -> (at: EpochMs, source: String) {
    if let personal = personalGapMs(all, now: input.now) {
      return (roundTo5Min(last.loggedAt + personal.gapMs), "based on the last \(personal.count) feeds")
    }
    let window = FeedWindows.window(for: input.baby, now: input.now)
    return (roundTo5Min(last.loggedAt + window.intervalMs), "typical at this age is \(window.label)")
  }

  public static func breastSide(_ input: InsightInput) -> Insight? {
    guard input.baby.feedingMode != .bottle else { return nil }
    guard let last = feeds(input.recentFeeds).last(where: { $0.feedKind != .bottle && $0.side != nil }),
          let side = last.side,
          input.now - last.loggedAt <= breastSideMaxAgeMs
    else { return nil }
    switch side {
    case .left:
      return Insight(kind: .breastSide, headline: "Last side: left", detail: "Try starting on the right next time.")
    case .right:
      return Insight(kind: .breastSide, headline: "Last side: right", detail: "Try starting on the left next time.")
    case .both:
      return Insight(kind: .breastSide, headline: "Last feed: both sides", detail: "Start on whichever feels fuller.")
    }
  }

  public static func lastNappy(_ input: InsightInput, calendar: Calendar = .current) -> Insight? {
    guard let nappy = input.lastNappy else {
      return Insight(kind: .lastNappy, headline: "No nappies logged yet", detail: "Log a wee or poo to keep track.")
    }
    let since = max(0, input.now - nappy.loggedAt)
    let what = HomeCopy.lastNappyKind(nappy)
    if since >= staleNappyMs {
      return Insight(
        kind: .lastNappy,
        headline: "No nappy logged for \(span(since))",
        detail: "Log nappies as you change them to keep this useful."
      )
    }
    return Insight(
      kind: .lastNappy,
      headline: "Last nappy \(span(since)) ago",
      detail: "\(what) at \(Clock.h12(nappy.loggedAt, calendar: calendar))"
    )
  }

  /// Commonly quoted awake-time ranges by age. Not an NHS target; tired signs matter more.
  public static func typicalAwake(dateOfBirth: EpochMs, now: EpochMs) -> WakeRange {
    let weeks = max(0, (now - dateOfBirth) / dayMs) / 7
    if weeks < 4 { return WakeRange(lowMin: 35, highMin: 60) }
    if weeks < 12 { return WakeRange(lowMin: 60, highMin: 90) }
    if weeks < 20 { return WakeRange(lowMin: 75, highMin: 120) }
    if weeks < 30 { return WakeRange(lowMin: 120, highMin: 180) }
    if weeks < 52 { return WakeRange(lowMin: 150, highMin: 240) }
    return WakeRange(lowMin: 240, highMin: 360)
  }

  public static func awake(_ input: InsightInput) -> Insight? {
    guard !input.asleep, let end = input.lastSleepEndMs, end <= input.now else { return nil }
    let awakeMs = input.now - end
    guard awakeMs < staleAwakeMs else { return nil }
    let range = typicalAwake(dateOfBirth: input.baby.dateOfBirth, now: input.now)
    let rangeText = "\(span(range.lowMin * minuteMs))–\(span(range.highMin * minuteMs))"
    if awakeMs > range.highMin * minuteMs {
      return Insight(
        kind: .awake,
        headline: "Awake \(span(awakeMs)), longer than usual",
        detail: "Typical at this age: \(rangeText). Look for yawns, rubbing eyes or staring."
      )
    }
    return Insight(
      kind: .awake,
      headline: "Awake for \(span(awakeMs))",
      detail: "Typical at this age: \(rangeText). Tired signs matter more than the clock."
    )
  }

  public static func tonightTog(_ input: InsightInput) -> Insight? {
    guard let tempC = input.baby.lastRoomTempC else {
      return Insight(
        kind: .tonightTog,
        headline: "Tonight's sleeping bag",
        detail: "Set the room temperature for a TOG suggestion."
      )
    }
    let advice = Clothing.advice(
      tempC: tempC, dateOfBirth: input.baby.dateOfBirth, weightGrams: input.baby.weightGrams, now: input.now
    )
    let layers = advice.layers.enumerated().map { item in
      item.offset == 0 ? item.element : item.element.prefix(1).lowercased() + item.element.dropFirst()
    }
    return Insight(
      kind: .tonightTog,
      headline: "Tonight at \(Clothing.formatTemp(tempC, fahrenheit: false))°C: \(advice.tog)",
      detail: layers.joined(separator: ", ")
    )
  }

  /// "45m", "2h", "1h 20m" (rounded down to the minute).
  public static func span(_ ms: Double) -> String {
    let total = Int((max(0, ms) / minuteMs).rounded(.down))
    let hours = total / 60
    let minutes = total % 60
    if hours == 0 { return "\(minutes)m" }
    if minutes == 0 { return "\(hours)h" }
    return "\(hours)h \(minutes)m"
  }

  static func roundTo5Min(_ ms: EpochMs) -> EpochMs {
    (ms / (5 * minuteMs)).rounded() * 5 * minuteMs
  }
}

public enum PartnerInvite {
  public static func message(babyName: String, code: String) -> String {
    "Join me on Scrunch so we can both log \(babyName)'s feeds, sleeps and nappies. "
      + "Open Scrunch, go to Kids, tap Join with a code and enter \(code)."
  }

  public static let howTo = "Send your partner or carer the code. They tap Join with a code on their Kids tab."
}
