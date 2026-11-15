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
    DisplayFormat(calendar: calendar).dayMonthTime(ms)
  }

  /// "Today", "Yesterday", "Tomorrow", "Fri 7 Nov", or "Fri 7 Nov 2025" outside this year.
  public static func timelineDay(_ ms: EpochMs, now: EpochMs, calendar: Calendar = .current) -> String {
    let dayStart = calendar.localMidnight(ms)
    let todayStart = calendar.localMidnight(now)
    if dayStart == todayStart { return String(localized: "Today", bundle: .module) }
    if dayStart == calendar.addingDays(-1, to: todayStart) { return String(localized: "Yesterday", bundle: .module) }
    if dayStart == calendar.addingDays(1, to: todayStart) { return String(localized: "Tomorrow", bundle: .module) }
    return shortDay(ms, now: now, calendar: calendar)
  }

  /// "Fri 7 Nov" (en-GB), with the year added when it isn't this year.
  public static func shortDay(_ ms: EpochMs, now: EpochMs, calendar: Calendar = .current) -> String {
    let format = DisplayFormat(calendar: calendar)
    let thisYear = calendar.component(.year, from: Date(epochMs: now))
    let year = calendar.component(.year, from: Date(epochMs: ms))
    return "\(format.weekdayShort(ms)) \(year == thisYear ? format.dayMonth(ms) : format.date(ms))"
  }
}
