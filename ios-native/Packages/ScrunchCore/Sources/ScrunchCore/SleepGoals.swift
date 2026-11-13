import Foundation

// Port of lib/sleepGoals.ts. Published 24h sleep ranges. Not a target. Not medical advice.

public struct SleepRange: Equatable, Sendable {
  public var lowHours: Double
  public var highHours: Double
}

public enum SleepGoals {
  static func ageDays(_ dateOfBirth: EpochMs, _ now: EpochMs) -> Double {
    max(0, (now - dateOfBirth) / dayMs)
  }

  public static func sleepDurationRange(dateOfBirth: EpochMs, now: EpochMs) -> SleepRange {
    let days = ageDays(dateOfBirth, now)
    // NSF Hirshkowitz et al. 2015 — newborns 14–17h.
    if days < 90 { return SleepRange(lowHours: 14, highHours: 17) }
    // AASM Paruthi et al. 2016 — 4–12 months 12–16h. Switch at 90 days.
    if days < 365 { return SleepRange(lowHours: 12, highHours: 16) }
    // NSF / AASM toddler 1–2 years.
    return SleepRange(lowHours: 11, highHours: 14)
  }

  public static func typicalFeedCount(dateOfBirth: EpochMs, now: EpochMs) -> Int {
    let days = ageDays(dateOfBirth, now)
    if days < 56 { return 8 }
    if days < 180 { return 6 }
    return 5
  }

  public static func typicalNappyCount(dateOfBirth: EpochMs, now: EpochMs) -> Int {
    ageDays(dateOfBirth, now) < 56 ? 8 : 6
  }

  /// Home tummy-time ring goal, in minutes.
  public static let tummyGoalMinutes = 30
}
