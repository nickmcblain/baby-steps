import Foundation

// Port of lib/clothingAdvice.ts — room temperature → TOG and layers.

public struct ClothingAdvice: Equatable, Sendable {
  public var tog: String
  public var layers: [String]
  public var why: String
  public var overheat: Bool
  public var extraLayer: Bool
}

public enum Clothing {
  struct Band {
    let maxTemp: Double
    let tog: String
    let layers: [String]
    let why: String
  }

  static let bands: [Band] = [
    Band(
      maxTemp: 16,
      tog: String(localized: "2.5 TOG", bundle: .module),
      layers: [String(localized: "Vest", bundle: .module), String(localized: "Sleepsuit", bundle: .module), String(localized: "2.5 TOG bag", bundle: .module), String(localized: "Light cellular blanket if still cool", bundle: .module)],
      why: String(localized: "A cool room needs a thicker bag and full layers.", bundle: .module)
    ),
    Band(
      maxTemp: 18,
      tog: String(localized: "2.5 TOG", bundle: .module),
      layers: [String(localized: "Vest", bundle: .module), String(localized: "Sleepsuit", bundle: .module), String(localized: "2.5 TOG sleeping bag", bundle: .module)],
      why: String(localized: "On the cool side of the usual 16–20°C range.", bundle: .module)
    ),
    Band(
      maxTemp: 20,
      tog: String(localized: "1.0 TOG", bundle: .module),
      layers: [String(localized: "Vest", bundle: .module), String(localized: "Sleepsuit or 1.0 TOG bag", bundle: .module)],
      why: String(localized: "This is the typical comfortable nursery band.", bundle: .module)
    ),
    Band(
      maxTemp: 22,
      tog: String(localized: "1.0 TOG", bundle: .module),
      layers: [String(localized: "Vest", bundle: .module), String(localized: "1.0 TOG bag or light sleepsuit", bundle: .module)],
      why: String(localized: "Warm enough that a light bag over a vest is plenty.", bundle: .module)
    ),
    Band(
      maxTemp: 24,
      tog: String(localized: "0.5 TOG", bundle: .module),
      layers: [String(localized: "Vest", bundle: .module), String(localized: "0.5 TOG bag or sheet", bundle: .module)],
      why: String(localized: "A warm room — keep bedding light.", bundle: .module)
    ),
    Band(
      maxTemp: 100,
      tog: String(localized: "0.2 TOG", bundle: .module),
      layers: [String(localized: "Nappy", bundle: .module), String(localized: "Short-sleeve vest if needed", bundle: .module)],
      why: String(localized: "At 24°C and above, babies overheat easily. Less is safer.", bundle: .module)
    ),
  ]

  /// Temperature screen range and step (°C).
  public static let minTempC: Double = 5
  public static let maxTempC: Double = 40
  public static let stepC: Double = 0.5
  public static let defaultTempC: Double = 18

  public static let overheatCheck = String(localized: "Feel the chest or back of the neck. Warm is good; sweaty means strip a layer.", bundle: .module)
  public static let finePrint = String(localized: "Guidance, not medical advice. No hats or hoods indoors for sleep.", bundle: .module)

  public static func advice(tempC: Double, dateOfBirth: EpochMs, weightGrams: Double, now: EpochMs) -> ClothingAdvice {
    let days = max(0, ((now - dateOfBirth) / dayMs).rounded(.down))
    let extraLayer = days < 92 || weightGrams < 5000
    let band = bands.first { tempC < $0.maxTemp } ?? bands[bands.count - 1]
    var layers = band.layers
    if extraLayer && tempC < 24 {
      layers.insert(String(localized: "Extra vest (newborn / smaller baby)", bundle: .module), at: 0)
    }
    return ClothingAdvice(
      tog: band.tog,
      layers: layers,
      why: extraLayer
        ? String(localized: "\(band.why) Under 3 months or a lighter baby can use one extra thin layer — never a hat indoors.", bundle: .module)
        : band.why,
      overheat: tempC >= 22,
      extraLayer: extraLayer
    )
  }

  public static func celsiusToFahrenheit(_ c: Double) -> Double { c * 9 / 5 + 32 }

  /// The big number on the temp screen, without unit: "18.5", "65.3".
  public static func formatTemp(_ tempC: Double, fahrenheit: Bool) -> String {
    let value = fahrenheit ? celsiusToFahrenheit(tempC) : tempC
    return value == value.rounded() ? jsNumber(value) : jsToFixed(value, 1)
  }

  /// Clamped ±0.5°C nudge.
  public static func nudge(_ tempC: Double, by deltaC: Double) -> Double {
    min(maxTempC, max(minTempC, jsRound((tempC + deltaC) * 2) / 2))
  }
}
