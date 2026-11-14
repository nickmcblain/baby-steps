import Foundation

// Grouping and windowing from components/EventList.tsx and the pattern charts.

public struct TimelineSection: Equatable, Sendable, Identifiable {
  public var id: EpochMs { dayStart }
  public var label: String
  public var dayStart: EpochMs
  public var items: [Event]
}

public enum Timeline {
  public static let initialPageSize = 40
  public static let filteredPageSize = 200
  public static let loadMoreStep = 20

  /// Groups consecutive events by local day. Future days come first (ascending), then
  /// today and the past in list order.
  public static func sections(_ events: [Event], now: EpochMs, calendar: Calendar = .current) -> [TimelineSection] {
    var groups: [TimelineSection] = []
    for event in events {
      let dayStart = calendar.localMidnight(event.loggedAt)
      if let last = groups.last, last.dayStart == dayStart {
        groups[groups.count - 1].items.append(event)
      } else {
        groups.append(TimelineSection(
          label: LoggedAt.timelineDay(event.loggedAt, now: now, calendar: calendar),
          dayStart: dayStart,
          items: [event]
        ))
      }
    }
    let todayStart = calendar.localMidnight(now)
    let upcoming = groups.filter { $0.dayStart > todayStart }.sorted { $0.dayStart < $1.dayStart }
    let rest = groups.filter { $0.dayStart <= todayStart }
    return upcoming + rest
  }

  /// The local-day window a pattern screen covers: `days` whole days ending on the day of
  /// `rangeEndMs`.
  public static func patternWindow(days: Int, rangeEndMs: EpochMs, calendar: Calendar = .current) -> (startMs: EpochMs, endMs: EpochMs) {
    let endDay = calendar.localMidnight(rangeEndMs - 1)
    return (calendar.addingDays(1 - days, to: endDay), calendar.addingDays(1, to: endDay))
  }

  /// Client-side filter (the deployment can't filter `events.list` by kind).
  public static func filter(_ events: [Event], kind: EventKind?, window: (startMs: EpochMs, endMs: EpochMs)?) -> [Event] {
    events.filter { event in
      if let kind, event.kind != kind { return false }
      guard let window else { return true }
      return event.loggedAt >= window.startMs && event.loggedAt < window.endMs
    }
  }
}

public struct PatternDay: Equatable, Sendable, Identifiable {
  public var id: EpochMs { dayStartMs }
  public var dayStartMs: EpochMs
  /// "Mon 3"
  public var label: String
  public var slices: [DaySlice]
}

public enum Patterns {
  public static let ranges = [7, 14]

  static let dayShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

  /// One row per local day, oldest first, with each item split across midnight.
  public static func days(_ items: [PatternItem], days: Int, rangeEndMs: EpochMs, calendar: Calendar = .current) -> [PatternDay] {
    let endDay = calendar.localMidnight(rangeEndMs - 1)
    var rows: [PatternDay] = (0..<days).reversed().map { offset in
      let dayStart = calendar.addingDays(-offset, to: endDay)
      let parts = calendar.dateComponents([.weekday, .day], from: Date(epochMs: dayStart))
      return PatternDay(dayStartMs: dayStart, label: "\(dayShort[parts.weekday! - 1]) \(parts.day!)", slices: [])
    }
    let index = Dictionary(uniqueKeysWithValues: rows.enumerated().map { ($1.dayStartMs, $0) })
    for item in items {
      for slice in WeekGrid.splitAcrossLocalDays(item.startMs, item.endMs, calendar: calendar) {
        if let row = index[slice.dayStartMs] { rows[row].slices.append(slice) }
      }
    }
    return rows
  }

  /// "1.5" or "—"
  public static func sessionsPerDay(_ value: Double) -> String {
    value > 0 ? jsToFixed(value, 1) : "—"
  }

  /// "2h 10m" or "—"
  public static func minutesPerDay(_ value: Double) -> String {
    let text = EventCopy.durationMinutes(jsRound(value))
    return text.isEmpty ? "—" : text
  }
}
