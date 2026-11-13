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
      tog: "2.5 TOG",
      layers: ["Vest", "Sleepsuit", "2.5 TOG bag", "Light cellular blanket if still cool"],
      why: "A cool room needs a thicker bag and full layers."
    ),
    Band(
      maxTemp: 18,
      tog: "2.5 TOG",
      layers: ["Vest", "Sleepsuit", "2.5 TOG sleeping bag"],
      why: "On the cool side of the usual 16–20°C range."
    ),
    Band(
      maxTemp: 20,
      tog: "1.0 TOG",
      layers: ["Vest", "Sleepsuit or 1.0 TOG bag"],
      why: "This is the typical comfortable nursery band."
    ),
    Band(
      maxTemp: 22,
      tog: "1.0 TOG",
      layers: ["Vest", "1.0 TOG bag or light sleepsuit"],
      why: "Warm enough that a light bag over a vest is plenty."
    ),
    Band(
      maxTemp: 24,
      tog: "0.5 TOG",
      layers: ["Vest", "0.5 TOG bag or sheet"],
      why: "A warm room — keep bedding light."
    ),
    Band(
      maxTemp: 100,
      tog: "0.2 TOG",
      layers: ["Nappy", "Short-sleeve vest if needed"],
      why: "At 24°C and above, babies overheat easily. Less is safer."
    ),
  ]

  /// Temperature screen range and step (°C).
  public static let minTempC: Double = 5
  public static let maxTempC: Double = 40
  public static let stepC: Double = 0.5
  public static let defaultTempC: Double = 18

  public static let overheatCheck = "Feel the chest or back of the neck. Warm is good; sweaty means strip a layer."
  public static let finePrint = "Guidance, not medical advice. No hats or hoods indoors for sleep."

  public static func advice(tempC: Double, dateOfBirth: EpochMs, weightGrams: Double, now: EpochMs) -> ClothingAdvice {
    let days = max(0, ((now - dateOfBirth) / dayMs).rounded(.down))
    let extraLayer = days < 92 || weightGrams < 5000
    let band = bands.first { tempC < $0.maxTemp } ?? bands[bands.count - 1]
    var layers = band.layers
    if extraLayer && tempC < 24 {
      layers.insert("Extra vest (newborn / smaller baby)", at: 0)
    }
    return ClothingAdvice(
      tog: band.tog,
      layers: layers,
      why: extraLayer
        ? "\(band.why) Under 3 months or a lighter baby can use one extra thin layer — never a hat indoors."
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
