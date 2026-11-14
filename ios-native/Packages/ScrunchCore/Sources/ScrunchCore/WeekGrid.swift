import Foundation

// Port of lib/weekGrid.ts. Local-calendar helpers for week / sleep charts.
// Day stepping uses calendar days rather than fixed 24h so DST weeks line up.

public struct WeekDayLabel: Equatable, Sendable {
  public var label: String
  public var dateNum: Int
  public var dayStartMs: EpochMs
}

public struct DaySlice: Equatable, Sendable {
  public var dayStartMs: EpochMs
  /// Minutes from local midnight, 0–1440.
  public var startMin: Double
  public var endMin: Double
}

public enum WeekGrid {
  static let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

  /// Monday 00:00 local for the week containing `at`.
  public static func startOfWeekMonday(_ at: EpochMs, calendar: Calendar = .current) -> EpochMs {
    let weekday = calendar.component(.weekday, from: Date(epochMs: at)) // 1 Sun … 7 Sat
    let daysFromMonday = weekday == 1 ? 6 : weekday - 2
    return calendar.addingDays(-daysFromMonday, to: calendar.localMidnight(at))
  }

  public static func startOfLocalDay(_ at: EpochMs, calendar: Calendar = .current) -> EpochMs {
    calendar.localMidnight(at)
  }

  public static func addDays(_ ms: EpochMs, _ days: Int, calendar: Calendar = .current) -> EpochMs {
    calendar.addingDays(days, to: ms)
  }

  public static func minutesOfDay(_ ms: EpochMs, calendar: Calendar = .current) -> Double {
    (ms - calendar.localMidnight(ms)) / minuteMs
  }

  public static func weekDayLabels(_ weekStartMs: EpochMs, calendar: Calendar = .current) -> [WeekDayLabel] {
    dayNames.enumerated().map { index, label in
      let dayStartMs = calendar.addingDays(index, to: weekStartMs)
      return WeekDayLabel(
        label: label,
        dateNum: calendar.component(.day, from: Date(epochMs: dayStartMs)),
        dayStartMs: dayStartMs
      )
    }
  }

  /// "3–9 Aug" or "28 Jul – 3 Aug".
  public static func formatWeekRange(_ weekStartMs: EpochMs, calendar: Calendar = .current) -> String {
    let start = calendar.dateComponents([.month, .day], from: Date(epochMs: weekStartMs))
    let end = calendar.dateComponents([.month, .day], from: Date(epochMs: calendar.addingDays(6, to: weekStartMs)))
    let startMonth = Clock.monthsShort[start.month! - 1]
    let endMonth = Clock.monthsShort[end.month! - 1]
    if start.month == end.month {
      return "\(start.day!)–\(end.day!) \(startMonth)"
    }
    return "\(start.day!) \(startMonth) – \(end.day!) \(endMonth)"
  }

  /// Split [startMs, endMs) into per-local-day slices.
  public static func splitAcrossLocalDays(_ startMs: EpochMs, _ endMs: EpochMs, calendar: Calendar = .current) -> [DaySlice] {
    guard endMs > startMs else { return [] }
    var slices: [DaySlice] = []
    var cursor = startMs
    while cursor < endMs {
      let dayStart = calendar.localMidnight(cursor)
      let dayEnd = calendar.addingDays(1, to: dayStart)
      let sliceEnd = min(endMs, dayEnd)
      let startMin = (cursor - dayStart) / minuteMs
      let endMin = (sliceEnd - dayStart) / minuteMs
      if endMin > startMin {
        slices.append(DaySlice(dayStartMs: dayStart, startMin: startMin, endMin: endMin))
      }
      cursor = sliceEnd
    }
    return slices
  }

  public static func formatHourLabel(_ hour: Int) -> String {
    let h = ((hour % 24) + 24) % 24
    if h == 0 { return "12am" }
    if h == 12 { return "12pm" }
    if h < 12 { return "\(h)am" }
    return "\(h - 12)pm"
  }
}
