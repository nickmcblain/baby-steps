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

  /// "Today", "Yesterday", "Tomorrow" or "18 Aug 2026".
  public static func timelineDay(_ ms: EpochMs, now: EpochMs, calendar: Calendar = .current) -> String {
    let dayStart = calendar.localMidnight(ms)
    let todayStart = calendar.localMidnight(now)
    if dayStart == todayStart { return "Today" }
    if dayStart == calendar.addingDays(-1, to: todayStart) { return "Yesterday" }
    if dayStart == calendar.addingDays(1, to: todayStart) { return "Tomorrow" }
    let parts = calendar.dateComponents([.year, .month, .day], from: Date(epochMs: ms))
    return "\(parts.day!) \(Clock.monthsShort[parts.month! - 1]) \(parts.year!)"
  }
}
