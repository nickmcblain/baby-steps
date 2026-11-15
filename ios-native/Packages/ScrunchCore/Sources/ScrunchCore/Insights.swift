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
      tonightTog(input, calendar: calendar),
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
        headline: String(localized: "Log a feed to see when the next is likely", bundle: .module),
        detail: String(localized: "We'll start with typical gaps for \(input.baby.name)'s age.", bundle: .module)
      )
    }
    let since = max(0, input.now - last.loggedAt)
    let sinceText = String(localized: "Last feed \(span(since)) ago", bundle: .module)
    if since >= staleFeedMs {
      return Insight(
        kind: .nextFeed,
        headline: String(localized: "No feed logged for \(span(since))", bundle: .module),
        detail: String(localized: "Log feeds as they happen and the estimate comes back.", bundle: .module)
      )
    }

    let (due, source) = nextFeedDue(after: last, feeds: all, input: input)
    if due <= input.now {
      return Insight(
        kind: .nextFeed,
        headline: String(localized: "Feed may be due now", bundle: .module),
        detail: String(localized: "\(sinceText) · watch for hunger cues", bundle: .module)
      )
    }
    return Insight(
      kind: .nextFeed,
      headline: String(localized: "Next feed likely around \(Clock.time(due, calendar: calendar))", bundle: .module),
      detail: "\(sinceText) · \(source)"
    )
  }

  /// The likely next feed time and where the gap comes from.
  static func nextFeedDue(after last: Event, feeds all: [Event], input: InsightInput) -> (at: EpochMs, source: String) {
    if let personal = personalGapMs(all, now: input.now) {
      return (roundTo5Min(last.loggedAt + personal.gapMs), String(localized: "based on the last \(personal.count) feeds", bundle: .module))
    }
    let window = FeedWindows.window(for: input.baby, now: input.now)
    return (roundTo5Min(last.loggedAt + window.intervalMs), String(localized: "typical at this age is \(window.label)", bundle: .module))
  }

  public static func breastSide(_ input: InsightInput) -> Insight? {
    guard input.baby.feedingMode != .bottle else { return nil }
    guard let last = feeds(input.recentFeeds).last(where: { $0.feedKind != .bottle && $0.side != nil }),
          let side = last.side,
          input.now - last.loggedAt <= breastSideMaxAgeMs
    else { return nil }
    switch side {
    case .left:
      return Insight(kind: .breastSide, headline: String(localized: "Last side: left", bundle: .module), detail: String(localized: "Try starting on the right next time.", bundle: .module))
    case .right:
      return Insight(kind: .breastSide, headline: String(localized: "Last side: right", bundle: .module), detail: String(localized: "Try starting on the left next time.", bundle: .module))
    case .both:
      return Insight(kind: .breastSide, headline: String(localized: "Last feed: both sides", bundle: .module), detail: String(localized: "Start on whichever feels fuller.", bundle: .module))
    }
  }

  public static func lastNappy(_ input: InsightInput, calendar: Calendar = .current) -> Insight? {
    guard let nappy = input.lastNappy else {
      return Insight(kind: .lastNappy, headline: String(localized: "No nappies logged yet", bundle: .module), detail: String(localized: "Log a wee or poo to keep track.", bundle: .module))
    }
    let since = max(0, input.now - nappy.loggedAt)
    let what = HomeCopy.lastNappyKind(nappy)
    if since >= staleNappyMs {
      return Insight(
        kind: .lastNappy,
        headline: String(localized: "No nappy logged for \(span(since))", bundle: .module),
        detail: String(localized: "Log nappies as you change them to keep this useful.", bundle: .module)
      )
    }
    return Insight(
      kind: .lastNappy,
      headline: String(localized: "Last nappy \(span(since)) ago", bundle: .module),
      detail: String(localized: "\(what) at \(Clock.time(nappy.loggedAt, calendar: calendar))", bundle: .module)
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
        headline: String(localized: "Awake \(span(awakeMs)), longer than usual", bundle: .module),
        detail: String(localized: "Typical at this age: \(rangeText). Look for yawns, rubbing eyes or staring.", bundle: .module)
      )
    }
    return Insight(
      kind: .awake,
      headline: String(localized: "Awake for \(span(awakeMs))", bundle: .module),
      detail: String(localized: "Typical at this age: \(rangeText). Tired signs matter more than the clock.", bundle: .module)
    )
  }

  public static func tonightTog(_ input: InsightInput, calendar: Calendar = .current) -> Insight? {
    guard let tempC = input.baby.lastRoomTempC else {
      return Insight(
        kind: .tonightTog,
        headline: String(localized: "Tonight's sleeping bag", bundle: .module),
        detail: String(localized: "Set the room temperature for a TOG suggestion.", bundle: .module)
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
      headline: String(localized: "Tonight at \(DisplayFormat(calendar: calendar).temperature(tempC)): \(advice.tog)", bundle: .module),
      detail: layers.joined(separator: ", ")
    )
  }

  /// "45m", "2h", "1h 20m" (rounded down to the minute).
  public static func span(_ ms: Double) -> String {
    let total = Int((max(0, ms) / minuteMs).rounded(.down))
    let hours = total / 60
    let minutes = total % 60
    if hours == 0 { return String(localized: "\(minutes)m", bundle: .module) }
    if minutes == 0 { return String(localized: "\(hours)h", bundle: .module) }
    return String(localized: "\(hours)h \(minutes)m", bundle: .module)
  }

  static func roundTo5Min(_ ms: EpochMs) -> EpochMs {
    (ms / (5 * minuteMs)).rounded() * 5 * minuteMs
  }
}

public enum PartnerInvite {
  public static func message(babyName: String, code: String) -> String {
    String(
      localized: "Join me on Scrunch so we can both log \(babyName)'s feeds, sleeps and nappies. Open Scrunch, go to Kids, tap Join with a code and enter \(code).",
      bundle: .module
    )
  }

  public static var howTo: String { String(localized: "Send your partner or carer the code. They tap Join with a code on their Kids tab.", bundle: .module) }
}
