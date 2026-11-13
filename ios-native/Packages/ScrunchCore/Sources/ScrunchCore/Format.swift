import Foundation

// Port of lib/format.ts.

public enum WeightUnit: String, Sendable { case kg, lb }
public enum HeightUnit: String, Sendable { case cm, inches = "in" }

public enum Format {
  static let gramsPerLb = 453.59237
  static let gramsPerOz = 28.349523125
  static let cmPerInch = 2.54

  public static func age(dateOfBirth: EpochMs, now: EpochMs) -> String {
    let days = Int(max(0, ((now - dateOfBirth) / dayMs).rounded(.down)))
    if days < 14 { return "\(days) day\(days == 1 ? "" : "s")" }
    let weeks = days / 7
    if weeks < 13 { return "\(weeks) week\(weeks == 1 ? "" : "s")" }
    let months = Int((Double(days) / 30.437).rounded(.down))
    if months < 24 { return "\(months) month\(months == 1 ? "" : "s")" }
    let years = months / 12
    let rem = months % 12
    if rem == 0 { return "\(years) year\(years == 1 ? "" : "s")" }
    return "\(years)y \(rem)mo"
  }

  public static func kg(_ grams: Double) -> String {
    let wholeKg = grams.truncatingRemainder(dividingBy: 1000) == 0
    return "\(jsToFixed(grams / 1000, wholeKg ? 0 : 2)) kg"
  }

  /// "3 Jan 2026" — DOB is stored as UTC midnight, so format in UTC.
  public static func dob(_ ms: EpochMs) -> String {
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    let parts = utc.dateComponents([.year, .month, .day], from: Date(epochMs: ms))
    return "\(parts.day!) \(Clock.monthsShort[parts.month! - 1]) \(parts.year!)"
  }

  /// UTC midnight for a calendar date, as `Date.UTC(y, m, d)`.
  public static func dobMs(year: Int, month: Int, day: Int) -> EpochMs {
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    return utc.date(from: DateComponents(year: year, month: month, day: day))!.epochMs
  }

  public static func gramsToKgParts(_ grams: Double) -> (kg: Int, tenths: Int) {
    let totalTenths = Int(jsRound(grams / 100))
    return (totalTenths / 10, totalTenths % 10)
  }

  public static func kgPartsToGrams(kg: Int, tenths: Int) -> Double {
    jsRound((Double(kg) + Double(tenths) / 10) * 1000)
  }

  public static func gramsToLbOz(_ grams: Double) -> (lb: Int, oz: Int) {
    let totalOz = Int(jsRound(grams / gramsPerOz))
    return (totalOz / 16, totalOz % 16)
  }

  public static func lbOzToGrams(lb: Int, oz: Int) -> Double {
    jsRound(Double(lb) * gramsPerLb + Double(oz) * gramsPerOz)
  }

  public static func weight(_ grams: Double, unit: WeightUnit = .kg) -> String {
    if unit == .lb {
      let parts = gramsToLbOz(grams)
      return "\(parts.lb) lb \(parts.oz) oz"
    }
    let parts = gramsToKgParts(grams)
    return parts.tenths == 0 ? "\(parts.kg) kg" : "\(parts.kg).\(parts.tenths) kg"
  }

  public static func cmToParts(_ cm: Double) -> (whole: Int, tenths: Int) {
    let totalTenths = Int(jsRound(cm * 10))
    return (totalTenths / 10, totalTenths % 10)
  }

  public static func cmPartsToCm(whole: Int, tenths: Int) -> Double {
    jsRound((Double(whole) + Double(tenths) / 10) * 10) / 10
  }

  public static func cmToFtIn(_ cm: Double) -> (ft: Int, inch: Int) {
    let totalInches = Int(jsRound(cm / cmPerInch))
    return (totalInches / 12, totalInches % 12)
  }

  public static func ftInToCm(ft: Int, inch: Int) -> Double {
    jsRound(Double(ft * 12 + inch) * cmPerInch * 10) / 10
  }

  public static func height(_ cm: Double, unit: HeightUnit = .cm) -> String {
    if unit == .inches {
      let parts = cmToFtIn(cm)
      return "\(parts.ft)′ \(parts.inch)″"
    }
    let parts = cmToParts(cm)
    return parts.tenths == 0 ? "\(parts.whole) cm" : "\(parts.whole).\(parts.tenths) cm"
  }

  public static func relative(_ loggedAt: EpochMs, now: EpochMs) -> String {
    let delta = max(0, now - loggedAt)
    let minutes = Int((delta / minuteMs).rounded(.down))
    if minutes < 1 { return "just now" }
    if minutes < 60 { return "\(minutes)m ago" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)h \(minutes % 60)m ago" }
    return "\(hours / 24)d ago"
  }
}
