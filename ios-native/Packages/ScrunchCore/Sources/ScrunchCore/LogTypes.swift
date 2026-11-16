import Foundation

/// Which log types make sense for a baby's age.
public enum LogTypes {
  /// Potty training rarely starts before the first birthday, so the potty log stays out
  /// of the way until then.
  public static let pottyFromDays: Double = 365

  public static func showsPotty(dateOfBirth: EpochMs, now: EpochMs) -> Bool {
    (now - dateOfBirth) / dayMs >= pottyFromDays
  }
}
