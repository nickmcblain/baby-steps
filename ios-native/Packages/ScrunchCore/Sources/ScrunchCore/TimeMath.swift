import Foundation

/// Milliseconds since the Unix epoch, as Convex stores them.
public typealias EpochMs = Double

public let minuteMs: Double = 60_000
public let hourMs: Double = 3_600_000
public let dayMs: Double = 86_400_000

public extension Date {
  init(epochMs: EpochMs) {
    self.init(timeIntervalSince1970: epochMs / 1000)
  }

  var epochMs: EpochMs { (timeIntervalSince1970 * 1000).rounded() }
}

/// Local-calendar helpers. Every function takes a `Calendar` so tests can pin a time zone;
/// the app passes `.current` (the device zone), matching the RN app's `new Date()` use.
extension Calendar {
  func hour(_ ms: EpochMs) -> Int { component(.hour, from: Date(epochMs: ms)) }

  func minuteOfDay(_ ms: EpochMs) -> Int {
    let parts = dateComponents([.hour, .minute], from: Date(epochMs: ms))
    return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
  }

  func localMidnight(_ ms: EpochMs) -> EpochMs {
    startOfDay(for: Date(epochMs: ms)).epochMs
  }

  /// Same wall-clock time `days` calendar days later (DST safe).
  func addingDays(_ days: Int, to ms: EpochMs) -> EpochMs {
    (date(byAdding: .day, value: days, to: Date(epochMs: ms)) ?? Date(epochMs: ms + Double(days) * dayMs)).epochMs
  }

  func at(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> EpochMs {
    date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!.epochMs
  }
}

public enum Clock {
  /// "14:05", or "2:05 PM" on a 12-hour clock.
  public static func time(_ ms: EpochMs, calendar: Calendar = .current) -> String {
    DisplayFormat(calendar: calendar).time(ms)
  }

  static func pad2(_ value: Int) -> String {
    value < 10 ? "0\(value)" : "\(value)"
  }
}

/// Formats a number the way JavaScript's `String(n)` does for the values this app shows:
/// integers without a decimal point, otherwise the shortest round-trip form.
public func jsNumber(_ value: Double) -> String {
  if value.isFinite, value == value.rounded(), abs(value) < 1e15 {
    return String(Int64(value))
  }
  return "\(value)"
}

/// JavaScript `Math.round` (halves round up, towards +∞).
public func jsRound(_ value: Double) -> Double {
  (value + 0.5).rounded(.down)
}

/// JavaScript `Number.prototype.toFixed`: exact ties round away from zero,
/// where `String(format: "%.1f")` rounds them to even (1.25 → "1.2" vs JS "1.3").
public func jsToFixed(_ value: Double, _ digits: Int) -> String {
  let scale = pow(10, Double(digits))
  let rounded = (value * scale).rounded(.toNearestOrAwayFromZero) / scale
  return String(format: "%.\(digits)f", rounded)
}
