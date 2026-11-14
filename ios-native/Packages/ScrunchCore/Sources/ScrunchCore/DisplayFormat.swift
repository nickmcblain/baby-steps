import Foundation

/// Weight display choice. `automatic` follows the region (kg, or lb/oz where the region uses US units);
/// UK parents often think in pounds and ounces, so they can pin it.
public enum WeightPreference: String, CaseIterable, Sendable {
  case automatic, kg, lbOz

  public static let storageKey = "units.weight"

  public static var stored: WeightPreference {
    UserDefaults.standard.string(forKey: storageKey).flatMap(WeightPreference.init(rawValue:)) ?? .automatic
  }
}

/// The one place units, durations, times and dates become text.
///
/// Units come from the locale's measurement system (UK and metric: kg, cm, ml, °C; US: lb/oz, ft/in,
/// fl oz, °F). Times follow the locale's hour cycle, which on device includes the 24-Hour Time setting.
/// The locale is taken from the calendar, so `Calendar.current` gives the user's settings and tests can
/// pin a time zone and locale together.
public struct DisplayFormat: Sendable {
  public var calendar: Calendar
  public var weightPreference: WeightPreference

  public init(calendar: Calendar = .current, weightPreference: WeightPreference = .stored) {
    self.calendar = calendar
    self.weightPreference = weightPreference
  }

  public static var current: DisplayFormat { DisplayFormat() }

  public var locale: Locale { calendar.locale ?? .autoupdatingCurrent }

  private var usesUSUnits: Bool { locale.measurementSystem == .us }

  // MARK: Units

  public var weightUnit: WeightUnit {
    switch weightPreference {
    case .kg: return .kg
    case .lbOz: return .lb
    case .automatic: return usesUSUnits ? .lb : .kg
    }
  }

  public var heightUnit: HeightUnit { usesUSUnits ? .inches : .cm }

  public var volumeUnit: UnitVolume { usesUSUnits ? .fluidOunces : .milliliters }

  public var temperatureUnit: UnitTemperature { UnitTemperature(forLocale: locale) }

  /// "3.4 kg" or "7 lb 8 oz". Grams are rounded to the 100 g / 1 oz the pickers use.
  public func weight(_ grams: Double, unit: WeightUnit? = nil) -> String {
    if (unit ?? weightUnit) == .lb {
      let parts = Format.gramsToLbOz(grams)
      return "\(measure(Double(parts.lb), UnitMass.pounds)) \(measure(Double(parts.oz), UnitMass.ounces))"
    }
    let parts = Format.gramsToKgParts(grams)
    return measure(Double(parts.kg * 10 + parts.tenths) / 10, UnitMass.kilograms, fraction: 0...1)
  }

  /// "50.5 cm" or "1′ 8″".
  public func length(_ cm: Double, unit: HeightUnit? = nil) -> String {
    if (unit ?? heightUnit) == .inches {
      let parts = Format.cmToFtIn(cm)
      return "\(parts.ft)′ \(parts.inch)″"
    }
    let parts = Format.cmToParts(cm)
    return measure(Double(parts.whole * 10 + parts.tenths) / 10, UnitLength.centimeters, fraction: 0...1)
  }

  /// "120 ml" or "4.1 fl oz". Feeds are stored in ml.
  public func volume(_ ml: Double) -> String {
    let value = Measurement(value: ml, unit: UnitVolume.milliliters).converted(to: volumeUnit).value
    return measure(value, volumeUnit, fraction: volumeUnit == .milliliters ? 0...0 : 0...1)
  }

  /// The short unit name for an amount field label, e.g. "ml".
  public var volumeSymbol: String {
    let formatter = MeasurementFormatter()
    formatter.locale = locale
    formatter.unitStyle = .medium
    return formatter.string(from: volumeUnit)
  }

  /// A typed amount in `volumeUnit`, converted to the ml we store.
  public func millilitres(fromInput value: Double) -> Double {
    jsRound(Measurement(value: value, unit: volumeUnit).converted(to: .milliliters).value)
  }

  /// "18°C" or "64°F" from a Celsius reading.
  public func temperature(_ celsius: Double, fraction: ClosedRange<Int> = 0...1) -> String {
    let value = Measurement(value: celsius, unit: UnitTemperature.celsius).converted(to: temperatureUnit).value
    return measure(value, temperatureUnit, fraction: fraction)
  }

  private func measure<U: Dimension>(_ value: Double, _ unit: U, fraction: ClosedRange<Int> = 0...0) -> String {
    Measurement(value: value, unit: unit).formatted(
      .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(fraction)))
        .locale(locale)
    )
  }

  // MARK: Durations

  /// "45 min", "1h", "1h 35m"; empty for zero.
  public func duration(minutes: Double) -> String {
    guard minutes.isFinite, minutes > 0 else { return "" }
    let total = Int(jsRound(minutes))
    if total < 60 { return String(localized: "\(total) min", bundle: .module) }
    let h = total / 60
    let m = total % 60
    return m == 0
      ? String(localized: "\(h)h", bundle: .module)
      : String(localized: "\(h)h \(m)m", bundle: .module)
  }

  // MARK: Times and dates

  public var uses24HourClock: Bool {
    switch locale.hourCycle {
    case .zeroToTwentyThree, .oneToTwentyFour: return true
    default: return false
    }
  }

  private var dateStyle: Date.FormatStyle {
    Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
  }

  /// "14:05" or "2:05 PM", per the hour cycle.
  public func time(_ ms: EpochMs) -> String {
    Date(epochMs: ms).formatted(dateStyle.hour().minute())
  }

  /// Chart axis hour: "15" on a 24-hour clock, "3 PM" on a 12-hour one.
  public func hourLabel(_ hour: Int) -> String {
    let h = ((hour % 24) + 24) % 24
    let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: h)) ?? Date()
    let style = uses24HourClock ? dateStyle.hour(.twoDigits(amPM: .omitted)) : dateStyle.hour(.defaultDigits(amPM: .abbreviated))
    return date.formatted(style)
  }

  /// "3 Jan 2026" (en-GB) or "Jan 3, 2026" (en-US).
  public func date(_ ms: EpochMs) -> String {
    Date(epochMs: ms).formatted(dateStyle.day().month(.abbreviated).year())
  }

  /// "20 Aug" or "Aug 20".
  public func dayMonth(_ ms: EpochMs) -> String {
    Date(epochMs: ms).formatted(dateStyle.day().month(.abbreviated))
  }

  /// "20 Aug · 14:30"
  public func dayMonthTime(_ ms: EpochMs) -> String {
    "\(dayMonth(ms)) · \(time(ms))"
  }

  /// "Mon"
  public func weekdayShort(_ ms: EpochMs) -> String {
    Date(epochMs: ms).formatted(dateStyle.weekday(.abbreviated))
  }

  /// "3–9 Aug" or "27 Jul – 2 Aug" (en-GB); "Aug 3 – 9" (en-US).
  public func dayRange(_ startMs: EpochMs, _ endMs: EpochMs) -> String {
    let style = Date.IntervalFormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).day().month(.abbreviated)
    return (Date(epochMs: startMs)..<Date(epochMs: endMs)).formatted(style)
  }
}
