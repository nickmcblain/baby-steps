import Foundation

/// Copy written for VoiceOver and chart descriptors, where "12:05" or "1h 5m" reads badly.
public enum Spoken {
  static func plural(_ count: Int, _ one: String, _ many: String? = nil) -> String {
    "\(count) \(count == 1 ? one : many ?? one + "s")"
  }

  /// "1 hour 3 minutes 5 seconds"; "0 seconds" at zero.
  public static func clock(_ ms: Double) -> String {
    let total = Int(max(0, (ms / 1000).rounded(.down)))
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    var parts: [String] = []
    if h > 0 { parts.append(plural(h, "hour")) }
    if m > 0 { parts.append(plural(m, "minute")) }
    if s > 0 || parts.isEmpty { parts.append(plural(s, "second")) }
    return parts.joined(separator: " ")
  }

  /// "1 hour 20 minutes"; "0 minutes" at zero.
  public static func minutes(_ minutes: Double) -> String {
    let total = Int(jsRound(max(0, minutes)))
    let h = total / 60
    let m = total % 60
    if h == 0 { return plural(m, "minute") }
    return m == 0 ? plural(h, "hour") : "\(plural(h, "hour")) \(plural(m, "minute"))"
  }

  /// Minutes after midnight in the user's clock style ("09:30" or "9:30 AM"); 1440 reads as "midnight".
  public static func timeOfDay(minutes: Double, calendar: Calendar = .current) -> String {
    let total = Int(jsRound(max(0, minutes)))
    if total >= 1440 { return String(localized: "midnight", bundle: .module) }
    let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: total / 60, minute: total % 60)) ?? Date()
    return DisplayFormat(calendar: calendar).time(date.epochMs)
  }

  /// One pattern row: "Nothing logged", or "2 logged, 1 hour 5 minutes in total".
  public static func patternDay(_ day: PatternDay, timed: Bool = true) -> String {
    guard !day.slices.isEmpty else { return "Nothing logged" }
    let count = "\(day.slices.count) logged"
    guard timed else { return count }
    let total = day.slices.reduce(0) { $0 + ($1.endMin - $1.startMin) }
    return total >= 1 ? "\(count), \(minutes(total)) in total" : count
  }

  /// Whole-chart summary: "7 days, 12 logged. Busiest: Mon 3 with 4. 2 days with nothing logged."
  public static func patternSummary(_ rows: [PatternDay]) -> String {
    let total = rows.reduce(0) { $0 + $1.slices.count }
    var sentences = ["\(plural(rows.count, "day")), \(total) logged."]
    if total > 0, let busiest = rows.max(by: { $0.slices.count < $1.slices.count }) {
      sentences.append("Busiest: \(busiest.label) with \(busiest.slices.count).")
    }
    let empty = rows.filter(\.slices.isEmpty).count
    if empty > 0, total > 0 {
      sentences.append("\(plural(empty, "day")) with nothing logged.")
    }
    return sentences.joined(separator: " ")
  }

  /// Home "today" read-out: "3 feeds, 4 nappies, 6 hours 20 minutes of sleep and 12 minutes of tummy time."
  public static func daySummary(feeds: Double, nappies: Double, sleepMinutes: Double, tummyMinutes: Double) -> String {
    let feedText = plural(Int(feeds), "feed")
    let nappyText = plural(Int(nappies), "nappy", "nappies")
    return "\(feedText), \(nappyText), \(minutes(sleepMinutes)) of sleep and \(minutes(tummyMinutes)) of tummy time."
  }

  public static func markerName(_ kind: WeekMarkerKind, count: Int) -> String {
    switch kind {
    case .feed: plural(count, "feed")
    case .nappy: plural(count, "nappy", "nappies")
    case .weight: plural(count, "weigh-in")
    case .height: plural(count, "height")
    case .custom: plural(count, "event")
    case .pump: plural(count, "pump")
    case .medicine: plural(count, "medicine")
    case .potty: plural(count, "potty", "potties")
    case .activity: plural(count, "activity", "activities")
    }
  }

  /// One week-chart column: "2 hours of sleep, 10 minutes of tummy time, 6 feeds, 5 nappies".
  public static func weekDay(
    dayStartMs: EpochMs,
    sleeps: [(startMs: EpochMs, endMs: EpochMs)],
    tummies: [(startMs: EpochMs, endMs: EpochMs)],
    markers: [(kind: WeekMarkerKind, atMs: EpochMs)],
    calendar: Calendar = .current
  ) -> String {
    func minutesOn(_ blocks: [(startMs: EpochMs, endMs: EpochMs)]) -> Double {
      blocks.flatMap { WeekGrid.splitAcrossLocalDays($0.startMs, $0.endMs, calendar: calendar) }
        .filter { $0.dayStartMs == dayStartMs }
        .reduce(0) { $0 + $1.endMin - $1.startMin }
    }
    var parts: [String] = []
    let sleep = minutesOn(sleeps)
    if sleep >= 1 { parts.append("\(minutes(sleep)) of sleep") }
    let tummy = minutesOn(tummies)
    if tummy >= 1 { parts.append("\(minutes(tummy)) of tummy time") }
    let today = markers.filter { WeekGrid.startOfLocalDay($0.atMs, calendar: calendar) == dayStartMs }
    for kind in WeekMarkerKind.allCases {
      let count = today.filter { $0.kind == kind }.count
      if count > 0 { parts.append(markerName(kind, count: count)) }
    }
    return parts.isEmpty ? "Nothing logged" : parts.joined(separator: ", ")
  }
}
