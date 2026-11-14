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
    if days < 14 { return String(localized: "\(days) days", bundle: .module) }
    let weeks = days / 7
    if weeks < 13 { return String(localized: "\(weeks) weeks", bundle: .module) }
    let months = Int((Double(days) / 30.437).rounded(.down))
    if months < 24 { return String(localized: "\(months) months", bundle: .module) }
    let years = months / 12
    let rem = months % 12
    if rem == 0 { return String(localized: "\(years) years", bundle: .module) }
    return String(localized: "\(years)y \(rem)mo", bundle: .module)
  }

  /// "3 Jan 2026" (en-GB). DOB is stored as UTC midnight, so format in UTC.
  public static func dob(_ ms: EpochMs, calendar: Calendar = .current) -> String {
    var utc = calendar
    utc.timeZone = TimeZone(identifier: "UTC")!
    return DisplayFormat(calendar: utc).date(ms)
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

  /// In the user's weight unit unless one is given.
  public static func weight(_ grams: Double, unit: WeightUnit? = nil) -> String {
    DisplayFormat.current.weight(grams, unit: unit)
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

  public static func height(_ cm: Double, unit: HeightUnit? = nil) -> String {
    DisplayFormat.current.length(cm, unit: unit)
  }

  public static func relative(_ loggedAt: EpochMs, now: EpochMs) -> String {
    let delta = max(0, now - loggedAt)
    let minutes = Int((delta / minuteMs).rounded(.down))
    if minutes < 1 { return String(localized: "just now", bundle: .module) }
    if minutes < 60 { return String(localized: "\(minutes)m ago", bundle: .module) }
    let hours = minutes / 60
    if hours < 24 { return String(localized: "\(hours)h \(minutes % 60)m ago", bundle: .module) }
    return String(localized: "\(hours / 24)d ago", bundle: .module)
  }
}
