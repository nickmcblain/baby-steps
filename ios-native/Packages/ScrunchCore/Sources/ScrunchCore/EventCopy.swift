import Foundation

// Port of lib/eventCopy.ts.

public enum EventCopy {
  static func capitalize(_ value: String) -> String {
    guard let first = value.first else { return value }
    return first.uppercased() + value.dropFirst()
  }

  public static func durationMinutes(_ minutes: Double, format: DisplayFormat = .current) -> String {
    format.duration(minutes: minutes)
  }

  static func sideWords(_ side: Side?) -> String {
    switch side {
    case .left: return String(localized: "left", bundle: .module)
    case .right: return String(localized: "right", bundle: .module)
    default: return String(localized: "both sides", bundle: .module)
    }
  }

  static func trailingMinutes(_ event: Event) -> String {
    guard let minutes = event.durationMinutes, minutes != 0 else { return "" }
    return " · " + String(localized: "\(jsNumber(minutes)) min", bundle: .module)
  }

  public static func feedSummary(_ event: Event, format: DisplayFormat = .current) -> String {
    if event.feedKind == .bottle {
      let milk = event.milk == .expressed
        ? String(localized: "Expressed", bundle: .module)
        : String(localized: "Formula", bundle: .module)
      let amount = event.amountMl.map(format.volume) ?? "? \(format.volumeSymbol)"
      return "\(amount) \(milk)"
    }
    return String(localized: "Breast \(sideWords(event.side))", bundle: .module) + trailingMinutes(event)
  }

  public static func nappySummary(_ event: Event) -> String {
    var bits: [String] = []
    if event.nappy == .wee || event.nappy == .both {
      bits.append(String(localized: "Wee \(capitalize(event.weeSize?.rawValue ?? ""))", bundle: .module).trimmingCharacters(in: .whitespaces))
    }
    if event.nappy == .poo || event.nappy == .both {
      bits.append(String(localized: "Poo \(capitalize(event.pooSize?.rawValue ?? ""))", bundle: .module).trimmingCharacters(in: .whitespaces))
    }
    return bits.isEmpty ? String(localized: "Nappy", bundle: .module) : bits.joined(separator: " · ")
  }

  public static func pumpSummary(_ event: Event, format: DisplayFormat = .current) -> String {
    let amount = event.amountMl.map { " · \(format.volume($0))" } ?? ""
    return "\(capitalize(sideWords(event.side)))\(trailingMinutes(event))\(amount)"
  }

  public static func activitySummary(_ event: Event, format: DisplayFormat = .current) -> String {
    let title = trimmed(event.title) ?? String(localized: "Activity", bundle: .module)
    let duration = event.durationMinutes.flatMap { $0 != 0 ? " · \(format.duration(minutes: $0))" : nil } ?? ""
    return "\(title)\(duration)"
  }

  public static func kindLabel(_ event: Event, now: EpochMs) -> String {
    switch event.kind {
    case .feed: return String(localized: "Feed", bundle: .module)
    case .nappy: return String(localized: "Nappy", bundle: .module)
    case .weight: return String(localized: "Weight", bundle: .module)
    case .height: return String(localized: "Height", bundle: .module)
    case .sleep: return String(localized: "Sleep", bundle: .module)
    case .tummy: return String(localized: "Tummy time", bundle: .module)
    case .custom: return event.loggedAt > now ? String(localized: "Upcoming", bundle: .module) : String(localized: "Event", bundle: .module)
    case .pump: return String(localized: "Pump", bundle: .module)
    case .medicine: return String(localized: "Medicine", bundle: .module)
    case .potty: return String(localized: "Potty", bundle: .module)
    case .activity: return String(localized: "Activity", bundle: .module)
    }
  }

  public static func title(_ event: Event, format: DisplayFormat = .current) -> String {
    switch event.kind {
    case .feed: return feedSummary(event, format: format)
    case .nappy, .potty: return nappySummary(event)
    case .weight: return event.weightGrams.map { format.weight($0) } ?? String(localized: "Weight", bundle: .module)
    case .height: return event.heightCm.map { format.length($0) } ?? String(localized: "Height", bundle: .module)
    case .sleep: return event.durationMinutes.map { format.duration(minutes: $0) } ?? String(localized: "Sleep", bundle: .module)
    case .tummy: return event.durationMinutes.map { format.duration(minutes: $0) } ?? String(localized: "Tummy time", bundle: .module)
    case .custom: return trimmed(event.title) ?? String(localized: "Event", bundle: .module)
    case .pump: return pumpSummary(event, format: format)
    case .medicine: return trimmed(event.title) ?? String(localized: "Medicine", bundle: .module)
    case .activity: return activitySummary(event, format: format)
    }
  }

  static func trimmed(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    return value
  }
}
