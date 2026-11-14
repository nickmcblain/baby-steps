import Foundation

// Port of lib/growth/lms.ts — UK-WHO centiles as printed in the Red Book (PCHR) 0–4 years chart.
//
// UK-WHO = UK90 at birth (term, 40 weeks), no centiles from birth to 2 weeks while weight settles,
// then WHO 2006 Child Growth Standards. `WHOLMSData` matches the WHO monthly tables and the RCPCH
// `rcpchgrowth` UK-WHO tables (github.com/rcpch/rcpchgrowth-python, data_tables/who/who_infants.json)
// to within 0.03% on M. The birth rows are UK90 at 40 weeks from `data_tables/uk90_preterm.json`.

public enum GrowthMetric: String, Sendable {
  case weight, length
}

public enum GrowthBand: String, Sendable {
  case veryLow = "very_low"
  case low
  case typical
  case high
  case veryHigh = "very_high"
  case unknown
}

public struct Centile: Sendable {
  public let label: String
  public let z: Double
}

public enum GrowthLMS {
  /// UK Red Book / UK-WHO printed centile lines.
  public static let ukCentiles: [Centile] = [
    Centile(label: "0.4th", z: -2.65207),
    Centile(label: "2nd", z: -2.05375),
    Centile(label: "9th", z: -1.34076),
    Centile(label: "25th", z: -0.67449),
    Centile(label: "50th", z: 0),
    Centile(label: "75th", z: 0.67449),
    Centile(label: "91st", z: 1.34076),
    Centile(label: "98th", z: 2.05375),
    Centile(label: "99.6th", z: 2.65207),
  ]

  /// The lines the growth chart draws (0.4th, 9th, 50th, 91st, 99.6th).
  public static let chartCentiles: [Centile] = ukCentiles.filter {
    ["0.4th", "9th", "50th", "91st", "99.6th"].contains($0.label)
  }

  static let msPerMonth = 30.4375 * dayMs

  public static func ageMonths(dateOfBirth: EpochMs, at: EpochMs) -> Double {
    max(0, (at - dateOfBirth) / msPerMonth)
  }

  static func table(_ metric: GrowthMetric, _ sex: Sex) -> [LMSRow] {
    (metric == .weight ? WHOLMSData.weight : WHOLMSData.length)[sex] ?? []
  }

  /// UK90 term (40 weeks) birth LMS used by UK-WHO at birth.
  static func ukBirth(_ metric: GrowthMetric, _ sex: Sex) -> (L: Double, M: Double, S: Double) {
    switch (metric, sex) {
    case (.weight, .boy): return (0.782, 3.5551, 0.12851)
    case (.weight, .girl): return (0.501, 3.413, 0.12481)
    case (.length, .boy): return (1, 50.94454, 0.04197628)
    case (.length, .girl): return (1, 50.01719, 0.0369674)
    }
  }

  /// Measurements on the day of birth use the birth centiles.
  static let birthWindowMonths = 1 / 30.4375
  /// UK-WHO draws no centiles between birth and 2 weeks.
  public static let twoWeeksMonths = 14 / 30.4375

  /// LMS for an age, or nil inside the birth-to-2-weeks gap.
  static func lms(_ metric: GrowthMetric, _ sex: Sex, month: Double) -> (L: Double, M: Double, S: Double)? {
    if month < birthWindowMonths { return ukBirth(metric, sex) }
    if month < twoWeeksMonths { return nil }
    return interpolate(table(metric, sex), month: month)
  }

  static func interpolate(_ table: [LMSRow], month: Double) -> (L: Double, M: Double, S: Double)? {
    guard let first = table.first, let last = table.last else { return nil }
    let clamped = min(max(month, first.month), last.month)
    var i = 0
    while i < table.count - 1, table[i + 1].month < clamped { i += 1 }
    let row = table[i]
    if i == table.count - 1 || row.month == clamped { return (row.L, row.M, row.S) }
    let next = table[i + 1]
    let t = (clamped - row.month) / (next.month - row.month)
    return (row.L + t * (next.L - row.L), row.M + t * (next.M - row.M), row.S + t * (next.S - row.S))
  }

  /// Measurement (kg or cm) for a z-score via LMS (Cole & Green).
  public static func valueFromZ(_ metric: GrowthMetric, sex: Sex, month: Double, z: Double) -> Double? {
    guard let lms = lms(metric, sex, month: month) else { return nil }
    if abs(lms.L) < 1e-8 { return lms.M * exp(lms.S * z) }
    return lms.M * pow(1 + lms.L * lms.S * z, 1 / lms.L)
  }

  /// SDS / z-score for a measurement (kg or cm).
  public static func zScore(_ metric: GrowthMetric, sex: Sex, month: Double, value: Double) -> Double? {
    guard value > 0, let lms = lms(metric, sex, month: month) else { return nil }
    if abs(lms.L) < 1e-8 { return log(value / lms.M) / lms.S }
    return (pow(value / lms.M, lms.L) - 1) / (lms.L * lms.S)
  }

  /// Approximate centile 0.1–99.9 from z (Abramowitz & Stegun normal CDF).
  public static func centileFromZ(_ z: Double) -> Double {
    let t = 1 / (1 + 0.2316419 * abs(z))
    let d = 0.3989423 * exp(-z * z / 2)
    let p = d * t * (0.3193815 + t * (-0.3565638 + t * (1.781478 + t * (-1.821256 + t * 1.330274))))
    let cdf = z > 0 ? 1 - p : p
    return min(99.9, max(0.1, cdf * 100))
  }

  public static func formatCentile(_ centile: Double) -> String {
    if centile < 1 || centile >= 99 { return "\(jsToFixed(centile, 1))th" }
    let rounded = Int(jsRound(centile))
    let mod10 = rounded % 10
    let mod100 = rounded % 100
    let suffix: String
    if mod10 == 1 && mod100 != 11 {
      suffix = "st"
    } else if mod10 == 2 && mod100 != 12 {
      suffix = "nd"
    } else if mod10 == 3 && mod100 != 13 {
      suffix = "rd"
    } else {
      suffix = "th"
    }
    return "\(rounded)\(suffix)"
  }

  public static func band(_ z: Double?) -> GrowthBand {
    guard let z, z.isFinite else { return .unknown }
    if z < -2.05 { return .veryLow }
    if z < -1.34 { return .low }
    if z > 2.05 { return .veryHigh }
    if z > 1.34 { return .high }
    return .typical
  }

  public static func bandLabel(_ band: GrowthBand) -> String {
    switch band {
    case .veryLow: return String(localized: "Below the 2nd centile", bundle: .module)
    case .low: return String(localized: "Between 2nd and 9th centile", bundle: .module)
    case .typical: return String(localized: "Within expected range", bundle: .module)
    case .high: return String(localized: "Between 91st and 98th centile", bundle: .module)
    case .veryHigh: return String(localized: "Above the 98th centile", bundle: .module)
    case .unknown: return String(localized: "Add sex to see UK chart", bundle: .module)
    }
  }

  public static func maxChartMonths(dateOfBirth: EpochMs, now: EpochMs) -> Double {
    min(24, max(6, (ageMonths(dateOfBirth: dateOfBirth, at: now) + 1).rounded(.up)))
  }

  /// "Latest ≈ 50th centile · Within expected range", or nil without a point.
  public static func latestStatus(_ metric: GrowthMetric, sex: Sex, dateOfBirth: EpochMs, latest: GrowthPoint) -> (text: String, band: GrowthBand)? {
    let month = ageMonths(dateOfBirth: dateOfBirth, at: latest.at)
    guard let z = zScore(metric, sex: sex, month: month, value: latest.value) else { return nil }
    let band = band(z)
    return (String(localized: "Latest ≈ \(formatCentile(centileFromZ(z))) centile · \(bandLabel(band))", bundle: .module), band)
  }

  public static var outsideRangeCaution: String { HealthRegion.current.growthOutsideRangeCaution }
}
