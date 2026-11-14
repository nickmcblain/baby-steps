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

  /// "Today", "Yesterday", "Tomorrow" or "18 Aug 2026".
  public static func timelineDay(_ ms: EpochMs, now: EpochMs, calendar: Calendar = .current) -> String {
    let dayStart = calendar.localMidnight(ms)
    let todayStart = calendar.localMidnight(now)
    if dayStart == todayStart { return String(localized: "Today", bundle: .module) }
    if dayStart == calendar.addingDays(-1, to: todayStart) { return String(localized: "Yesterday", bundle: .module) }
    if dayStart == calendar.addingDays(1, to: todayStart) { return String(localized: "Tomorrow", bundle: .module) }
    return DisplayFormat(calendar: calendar).date(ms)
  }
}
