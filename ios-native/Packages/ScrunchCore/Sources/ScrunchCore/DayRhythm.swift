import Foundation

// Port of lib/dayRhythm.ts — the 7:00–7:00 day bar.
//
// Enough logged days → shade the slots they are usually asleep.
// Thin logs → an age shape sized from NHS totals. Clock placement is ours.
// NHS does not publish a timetable.
// https://www.nhs.uk/baby/caring-for-a-newborn/helping-your-baby-to-sleep/

public enum RhythmKind: String, Sendable, Equatable {
  case night, nap, awake
}

public struct RhythmSegment: Equatable, Sendable {
  /// Minutes after 7:00, 0–1440.
  public var start: Double
  public var end: Double
  public var kind: RhythmKind

  public init(start: Double, end: Double, kind: RhythmKind) {
    self.start = start
    self.end = end
    self.kind = kind
  }
}

public struct NightWindow: Equatable, Sendable {
  public var bedMin: Double
  public var wakeMin: Double

  public init(bedMin: Double, wakeMin: Double) {
    self.bedMin = bedMin
    self.wakeMin = wakeMin
  }

  /// Parent-set night. 7pm–7am is the starting point for "sleeps through".
  public static let `default` = NightWindow(bedMin: 19 * 60, wakeMin: 7 * 60)
}

public struct DayRhythm: Equatable, Sendable {
  public enum Source: String, Sendable { case logs, nhs }
  public var segments: [RhythmSegment]
  public var source: Source
  public var caption: String
}

public struct RhythmSleep: Equatable, Sendable {
  public var startMs: EpochMs
  public var endMs: EpochMs

  public init(startMs: EpochMs, endMs: EpochMs) {
    self.startMs = startMs
    self.endMs = endMs
  }
}

public struct SleepCountdown: Equatable, Sendable {
  public var inMs: Double
  public var kind: RhythmKind
}

public enum DayRhythmEngine {
  static let day: Double = 1440
  static let dayStart: Double = 7 * 60
  static let slot: Double = 30
  static let slots = 48
  static let minDays = 3
  static let minOverlapMs: Double = 15 * 60_000
  static let nightMin: Double = 4 * 60
  static let nightMax: Double = 14 * 60

  public static func nightLengthMin(bedMin: Double, wakeMin: Double) -> Double {
    mod(wakeMin - bedMin + 1440, 1440)
  }

  public static func validNight(_ night: NightWindow) -> Bool {
    let length = nightLengthMin(bedMin: night.bedMin, wakeMin: night.wakeMin)
    return length >= nightMin && length <= nightMax
  }

  public static func dayBarOffset(_ ms: EpochMs, calendar: Calendar = .current) -> Double {
    mod(Double(calendar.minuteOfDay(ms)) - dayStart + day, day)
  }

  /// Time until the next nap or night block. `inMs` is 0 when that window has started.
  public static func nextSleepCountdown(
    _ segments: [RhythmSegment],
    now: EpochMs,
    calendar: Calendar = .current
  ) -> SleepCountdown? {
    let sleep = segments.filter { $0.kind != .awake }
    guard !sleep.isEmpty else { return nil }
    let offset = dayBarOffset(now, calendar: calendar)
    if let current = sleep.first(where: { offset >= $0.start && offset < $0.end }) {
      return SleepCountdown(inMs: 0, kind: current.kind)
    }
    var next: RhythmSegment?
    for segment in sleep where segment.start > offset {
      if next == nil || segment.start < next!.start { next = segment }
    }
    if let next {
      return SleepCountdown(inMs: (next.start - offset) * 60_000, kind: next.kind)
    }
    let first = sleep.reduce(sleep[0]) { $1.start < $0.start ? $1 : $0 }
    return SleepCountdown(inMs: (day - offset + first.start) * 60_000, kind: first.kind)
  }

  public static func recommendedDay(
    dateOfBirth: EpochMs,
    now: EpochMs,
    sleeps: [RhythmSleep],
    night: NightWindow? = nil,
    calendar: Calendar = .current
  ) -> DayRhythm {
    let days = max(0, (now - dateOfBirth) / 86_400_000)
    let fromLogs = rhythmFromLogs(sleeps, calendar: calendar)
    if let night, validNight(night) {
      let base = fromLogs ?? nhsShape(days)
      return DayRhythm(
        segments: applyNightWindow(base, night),
        source: fromLogs != nil ? .logs : .nhs,
        caption: fromLogs != nil
          ? "Their daytime sleep, with the night you set."
          : "Night you set. Daytime naps still follow the age shape."
      )
    }
    if let fromLogs {
      return DayRhythm(
        segments: fromLogs,
        source: .logs,
        caption: "Where they usually sleep. Last 2 weeks. Cues first."
      )
    }
    return DayRhythm(segments: nhsShape(days), source: .nhs, caption: nhsCaption(days))
  }

  // MARK: - Internals

  static func applyNightWindow(_ segments: [RhythmSegment], _ night: NightWindow) -> [RhythmSegment] {
    let cuts = nightBarRanges(bedMin: night.bedMin, wakeMin: night.wakeMin)
    var kept = segments.filter { $0.kind != .awake }
    for cut in cuts {
      kept = kept.flatMap { subtract($0, cut) }
    }
    for cut in cuts {
      kept.append(RhythmSegment(start: cut.start, end: cut.end, kind: .night))
    }
    return cover(kept)
  }

  static func nightBarRanges(bedMin: Double, wakeMin: Double) -> [(start: Double, end: Double)] {
    let start = mod(bedMin - dayStart + day, day)
    var end = mod(wakeMin - dayStart + day, day)
    if end == 0 { end = day }
    if end > start { return [(start, end)] }
    var ranges: [(start: Double, end: Double)] = [(start, day)]
    if end > 0 { ranges.append((0, end)) }
    return ranges
  }

  static func subtract(_ segment: RhythmSegment, _ cut: (start: Double, end: Double)) -> [RhythmSegment] {
    if segment.end <= cut.start || segment.start >= cut.end { return [segment] }
    var out: [RhythmSegment] = []
    if segment.start < cut.start {
      out.append(RhythmSegment(start: segment.start, end: cut.start, kind: segment.kind))
    }
    if segment.end > cut.end {
      out.append(RhythmSegment(start: cut.end, end: segment.end, kind: segment.kind))
    }
    return out.filter { $0.end > $0.start }
  }

  static func nhsCaption(_ days: Double) -> String {
    if days < 90 { return "About 18h in short bursts. NHS, not a timetable." }
    if days < 180 { return "A longer night may start now. NHS, not a timetable." }
    if days < 365 { return "About 15h, mostly at night. NHS, not a timetable." }
    if days < 730 { return "About 12–15h, with a daytime nap. NHS, not a timetable." }
    return "About 12–14h, nap included. NHS, not a timetable."
  }

  /// Clock minutes → bar minutes. End of 7:00 is 1440, not 0.
  static func block(_ startClock: Double, _ endClock: Double, _ kind: RhythmKind) -> RhythmSegment {
    let start = mod(startClock - dayStart + day, day)
    var end = mod(endClock - dayStart + day, day)
    if end == 0 { end = day }
    return RhythmSegment(start: start, end: end, kind: kind)
  }

  static func nhsShape(_ days: Double) -> [RhythmSegment] {
    if days < 90 {
      var blocks: [RhythmSegment] = []
      var t: Double = 0
      while t < day {
        let clock = mod(dayStart + t, day)
        let kind: RhythmKind = clock >= 19 * 60 || clock < dayStart ? .night : .nap
        blocks.append(RhythmSegment(start: t, end: t + 180, kind: kind))
        t += 240
      }
      return cover(blocks)
    }
    if days < 180 {
      return cover([
        block(20 * 60, 4 * 60, .night),
        block(9 * 60 + 30, 11 * 60, .nap),
        block(13 * 60, 14 * 60 + 30, .nap),
        block(16 * 60 + 30, 18 * 60, .nap),
      ])
    }
    if days < 365 {
      return cover([
        block(19 * 60, dayStart, .night),
        block(9 * 60 + 30, 11 * 60, .nap),
        block(14 * 60, 15 * 60 + 30, .nap),
      ])
    }
    if days < 730 {
      return cover([
        block(19 * 60, 6 * 60 + 30, .night),
        block(12 * 60 + 30, 14 * 60 + 30, .nap),
      ])
    }
    return cover([
      block(19 * 60 + 30, 6 * 60 + 30, .night),
      block(13 * 60, 14 * 60 + 30, .nap),
    ])
  }

  static func barDayOrigin(_ ms: EpochMs, calendar: Calendar) -> EpochMs {
    let date = Date(epochMs: ms)
    var origin = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: date)!
    if date < origin {
      origin = calendar.date(byAdding: .day, value: -1, to: origin)!
      origin = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: origin)!
    }
    return origin.epochMs
  }

  static func nextBarDay(_ origin: EpochMs, calendar: Calendar) -> EpochMs {
    let next = calendar.date(byAdding: .day, value: 1, to: Date(epochMs: origin))!
    return calendar.date(bySettingHour: 7, minute: 0, second: 0, of: next)!.epochMs
  }

  static func rhythmFromLogs(_ sleeps: [RhythmSleep], calendar: Calendar) -> [RhythmSegment]? {
    var slotDays = Array(repeating: Set<EpochMs>(), count: slots)
    var anyDay = Set<EpochMs>()

    for sleep in sleeps where sleep.endMs > sleep.startMs {
      var origin = barDayOrigin(sleep.startMs, calendar: calendar)
      let last = barDayOrigin(sleep.endMs - 1, calendar: calendar)
      while origin <= last {
        anyDay.insert(origin)
        for i in 0..<slots {
          let slotStart = origin + Double(i) * slot * 60_000
          let slotEnd = slotStart + slot * 60_000
          let overlap = min(sleep.endMs, slotEnd) - max(sleep.startMs, slotStart)
          if overlap >= minOverlapMs { slotDays[i].insert(origin) }
        }
        let stepped = nextBarDay(origin, calendar: calendar)
        if stepped <= origin { break }
        origin = stepped
      }
    }

    guard anyDay.count >= minDays else { return nil }
    let asleep = slotDays.map { $0.count * 2 >= anyDay.count }
    guard asleep.contains(true) else { return nil }

    var blocks: [RhythmSegment] = []
    var i = 0
    while i < slots {
      if !asleep[i] {
        i += 1
        continue
      }
      let start = Double(i) * slot
      let night = start >= 12 * 60
      var j = i + 1
      while j < slots, asleep[j], (Double(j) * slot >= 12 * 60) == night { j += 1 }
      blocks.append(RhythmSegment(start: start, end: Double(j) * slot, kind: night ? .night : .nap))
      i = j
    }
    return cover(blocks)
  }

  static func cover(_ blocks: [RhythmSegment]) -> [RhythmSegment] {
    let sorted = blocks.sorted { $0.start < $1.start }
    var out: [RhythmSegment] = []
    var cursor: Double = 0
    for block in sorted {
      if block.start > cursor { out.append(RhythmSegment(start: cursor, end: block.start, kind: .awake)) }
      out.append(block)
      cursor = block.end
    }
    if cursor < day { out.append(RhythmSegment(start: cursor, end: day, kind: .awake)) }
    return out
  }

  static func mod(_ a: Double, _ n: Double) -> Double {
    let r = a.truncatingRemainder(dividingBy: n)
    return r < 0 ? r + n : r
  }
}
