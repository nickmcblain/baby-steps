import Foundation

// Port of lib/sleepOffer.ts — next-nap prediction from the baby's own daytime wake gaps.

public struct SleepSegment: Equatable, Sendable {
  public var startMs: EpochMs
  public var endMs: EpochMs
  public var durationMinutes: Double

  public init(startMs: EpochMs, endMs: EpochMs, durationMinutes: Double) {
    self.startMs = startMs
    self.endMs = endMs
    self.durationMinutes = durationMinutes
  }

  public init(_ item: PatternItem) {
    self.init(startMs: item.startMs, endMs: item.endMs, durationMinutes: item.durationMinutes)
  }
}

public struct WakeGap: Equatable, Sendable {
  public var gapMs: Double
  public var nextStartMs: EpochMs
}

public struct NapOffer: Equatable, Sendable {
  public var label: String
  public var subline: String
}

public enum SleepOffer {
  static let minGapMs: Double = 15 * 60_000
  static let fiveMinMs: Double = 5 * 60_000
  static let minGaps = 5
  static let minDays = 3

  static func isNightStart(_ ms: EpochMs, calendar: Calendar) -> Bool {
    let hour = calendar.hour(ms)
    return hour >= 19 || hour < 7
  }

  static func localDayKey(_ ms: EpochMs, calendar: Calendar) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: Date(epochMs: ms))
    return "\(parts.year!)-\(parts.month!)-\(parts.day!)"
  }

  public static func daytimeWakeGaps(_ sleeps: [SleepSegment], calendar: Calendar = .current) -> [WakeGap] {
    let sorted = sleeps.sorted { $0.startMs < $1.startMs }
    guard sorted.count > 1 else { return [] }
    var gaps: [WakeGap] = []
    for i in 0..<(sorted.count - 1) {
      let next = sorted[i + 1]
      if isNightStart(next.startMs, calendar: calendar) { continue }
      let gapMs = next.startMs - sorted[i].endMs
      if gapMs < minGapMs { continue }
      gaps.append(WakeGap(gapMs: gapMs, nextStartMs: next.startMs))
    }
    return gaps
  }

  static func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    let mid = sorted.count / 2
    if sorted.count % 2 == 0 { return (sorted[mid - 1] + sorted[mid]) / 2 }
    return sorted[mid]
  }

  /// Median personal daytime wake gap, rounded to 5 minutes; nil when there isn't enough data.
  public static func personalWakeGap(_ sleeps: [SleepSegment], calendar: Calendar = .current) -> Double? {
    var gaps = daytimeWakeGaps(sleeps, calendar: calendar)
    if gaps.count >= 10 {
      let drop = gaps.count / 10
      gaps = Array(gaps.sorted { $0.gapMs < $1.gapMs }.prefix(gaps.count - drop))
    }
    let days = Set(gaps.map { localDayKey($0.nextStartMs, calendar: calendar) })
    if gaps.count < minGaps || days.count < minDays { return nil }
    return jsRound(median(gaps.map(\.gapMs)) / fiveMinMs) * fiveMinMs
  }

  /// Predicted next nap start (last wake + personal median gap), or nil without enough data.
  public static func predictedNapAt(
    sleeps: [SleepSegment],
    lastSleepEndMs: EpochMs?,
    calendar: Calendar = .current
  ) -> EpochMs? {
    guard let lastSleepEndMs, let median = personalWakeGap(sleeps, calendar: calendar) else { return nil }
    return lastSleepEndMs + median
  }

  public static func predictedNapLabel(
    sleeps: [SleepSegment],
    lastSleepEndMs: EpochMs?,
    lastSleepMinutes: Double?,
    asleep: Bool,
    now: EpochMs,
    calendar: Calendar = .current
  ) -> NapOffer {
    if asleep || (lastSleepEndMs.map { $0 > now } ?? false) {
      return NapOffer(label: "Asleep", subline: "")
    }
    guard let nextOfferAt = predictedNapAt(sleeps: sleeps, lastSleepEndMs: lastSleepEndMs, calendar: calendar) else {
      return NapOffer(label: "Watch cues", subline: "Not enough of a daytime pattern yet.")
    }
    let shortNap = lastSleepMinutes.map { $0 < 30 } ?? false
    let shortLine = "A short nap still counts."
    if now >= nextOfferAt {
      return NapOffer(
        label: "Offer a nap",
        subline: shortNap ? shortLine : "A guess from their usual gap. Cues first."
      )
    }
    return NapOffer(
      label: "Often ready around \(Clock.h12(nextOfferAt, calendar: calendar))",
      subline: shortNap ? shortLine : "From their last two weeks"
    )
  }
}
