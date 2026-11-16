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
    let format = DisplayFormat(calendar: calendar)
    return (0..<7).map { index in
      let dayStartMs = calendar.addingDays(index, to: weekStartMs)
      return WeekDayLabel(
        label: format.weekdayShort(dayStartMs),
        dateNum: calendar.component(.day, from: Date(epochMs: dayStartMs)),
        dayStartMs: dayStartMs
      )
    }
  }

  /// "3–9 Aug" or "28 Jul – 3 Aug" (en-GB).
  public static func formatWeekRange(_ weekStartMs: EpochMs, calendar: Calendar = .current) -> String {
    DisplayFormat(calendar: calendar).dayRange(weekStartMs, calendar.addingDays(6, to: weekStartMs))
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

  /// "15" on a 24-hour clock, "3 PM" on a 12-hour one.
  public static func formatHourLabel(_ hour: Int, calendar: Calendar = .current) -> String {
    DisplayFormat(calendar: calendar).hourLabel(hour)
  }
}
