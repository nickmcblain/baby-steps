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

  /// "3h 12m since last feed" for each feed and nappy, keyed by event id. Gaps of a day
  /// or more aren't shown: by then it's a gap in logging, not in care.
  public static func gaps(_ events: [Event], now: EpochMs) -> [EventID: String] {
    var result: [EventID: String] = [:]
    for (kind, noun) in [(EventKind.feed, "feed"), (.nappy, "nappy")] {
      let sorted = events.filter { $0.kind == kind && $0.loggedAt <= now }.sorted { $0.loggedAt < $1.loggedAt }
      for (previous, current) in zip(sorted, sorted.dropFirst()) {
        let minutes = (current.loggedAt - previous.loggedAt) / minuteMs
        guard minutes >= 1, minutes < 24 * 60 else { continue }
        result[current.id] = "\(EventCopy.durationMinutes(minutes)) since last \(noun)"
      }
    }
    return result
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

  /// One row per local day, oldest first, with each item split across midnight.
  public static func days(_ items: [PatternItem], days: Int, rangeEndMs: EpochMs, calendar: Calendar = .current) -> [PatternDay] {
    let endDay = calendar.localMidnight(rangeEndMs - 1)
    let format = DisplayFormat(calendar: calendar)
    var rows: [PatternDay] = (0..<days).reversed().map { offset in
      let dayStart = calendar.addingDays(-offset, to: endDay)
      let day = calendar.component(.day, from: Date(epochMs: dayStart))
      return PatternDay(dayStartMs: dayStart, label: "\(format.weekdayShort(dayStart)) \(day)", slices: [])
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

  /// Days in the range with at least one log.
  public static func loggedDays(_ rows: [PatternDay]) -> Int {
    rows.filter { !$0.slices.isEmpty }.count
  }

  /// Below this many logged days, averages are shown with a plain warning.
  public static let sparseDays = 3

  /// "Only 1 day logged in the last 7, so these numbers are rough for now." or nil.
  public static func sparseNote(loggedDays: Int, days: Int) -> String? {
    guard loggedDays > 0, loggedDays < min(sparseDays, days) else { return nil }
    let dayWord = loggedDays == 1 ? "day" : "days"
    return "Only \(loggedDays) \(dayWord) logged in the last \(days), so these numbers are rough for now."
  }

  /// Feeds and bottle millilitres per local day, oldest first. Averages are over the days
  /// that have a feed, so a gap in logging doesn't read as a baby who stopped eating.
  public static func feedTotals(_ events: [Event], days: Int, rangeEndMs: EpochMs, calendar: Calendar = .current) -> FeedTotals {
    let endDay = calendar.localMidnight(rangeEndMs - 1)
    let format = DisplayFormat(calendar: calendar)
    var rows: [FeedDayTotal] = (0..<days).reversed().map { offset in
      let dayStart = calendar.addingDays(-offset, to: endDay)
      let day = calendar.component(.day, from: Date(epochMs: dayStart))
      return FeedDayTotal(dayStartMs: dayStart, label: "\(format.weekdayShort(dayStart)) \(day)", feeds: 0, ml: 0)
    }
    let index = Dictionary(uniqueKeysWithValues: rows.enumerated().map { ($1.dayStartMs, $0) })
    for event in events where event.kind == .feed {
      guard let row = index[calendar.localMidnight(event.loggedAt)] else { continue }
      rows[row].feeds += 1
      rows[row].ml += max(0, event.amountMl ?? 0)
    }
    let logged = rows.filter { $0.feeds > 0 }
    let count = Double(max(1, logged.count))
    return FeedTotals(
      days: rows,
      loggedDays: logged.count,
      feedsPerDay: Double(logged.reduce(0) { $0 + $1.feeds }) / count,
      mlPerDay: logged.reduce(0) { $0 + $1.ml } / count
    )
  }

  /// "6.5", "6"
  public static func perDay(_ value: Double) -> String {
    jsNumber(jsRound(value * 10) / 10)
  }
}

public struct FeedDayTotal: Equatable, Sendable, Identifiable {
  public var id: EpochMs { dayStartMs }
  public var dayStartMs: EpochMs
  /// "Mon 3"
  public var label: String
  public var feeds: Int
  public var ml: Double
}

public struct FeedTotals: Equatable, Sendable {
  public var days: [FeedDayTotal]
  public var loggedDays: Int
  public var feedsPerDay: Double
  public var mlPerDay: Double
}
