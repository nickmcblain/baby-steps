import Foundation

// Port of lib/loggedAt.ts.

public enum LoggedAt {
  public static func snapToMinute(_ ms: EpochMs) -> EpochMs {
    jsRound(ms / minuteMs) * minuteMs
  }

  public static func nowSnapped(_ now: EpochMs = Date().epochMs) -> EpochMs {
    snapToMinute(now)
  }

  /// The value a log screen saves: snapped to the minute and, unless future dates are
  /// allowed (custom events), never after now.
  public static func resolve(_ picked: EpochMs, allowFuture: Bool, now: EpochMs = Date().epochMs) -> EpochMs {
    let snapped = snapToMinute(picked)
    return allowFuture ? snapped : min(snapped, nowSnapped(now))
  }

  /// "20 Aug · 14:30"
  public static func format(_ ms: EpochMs, calendar: Calendar = .current) -> String {
    let parts = calendar.dateComponents([.month, .day], from: Date(epochMs: ms))
    return "\(parts.day!) \(Clock.monthsShort[parts.month! - 1]) · \(Clock.h24(ms, calendar: calendar))"
  }

  /// "Today", "Yesterday", "Tomorrow", "Fri 7 Nov", or "Fri 7 Nov 2025" outside this year.
  public static func timelineDay(_ ms: EpochMs, now: EpochMs, calendar: Calendar = .current) -> String {
    let dayStart = calendar.localMidnight(ms)
    let todayStart = calendar.localMidnight(now)
    if dayStart == todayStart { return "Today" }
    if dayStart == calendar.addingDays(-1, to: todayStart) { return "Yesterday" }
    if dayStart == calendar.addingDays(1, to: todayStart) { return "Tomorrow" }
    return shortDay(ms, now: now, calendar: calendar)
  }

  /// "Fri 7 Nov", with the year added when it isn't this year.
  public static func shortDay(_ ms: EpochMs, now: EpochMs, calendar: Calendar = .current) -> String {
    let parts = calendar.dateComponents([.year, .month, .day, .weekday], from: Date(epochMs: ms))
    let thisYear = calendar.component(.year, from: Date(epochMs: now))
    let label = "\(Patterns.dayShort[parts.weekday! - 1]) \(parts.day!) \(Clock.monthsShort[parts.month! - 1])"
    return parts.year == thisYear ? label : "\(label) \(parts.year!)"
  }
}
