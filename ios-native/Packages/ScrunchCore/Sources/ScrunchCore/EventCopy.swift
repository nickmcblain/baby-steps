import Foundation

// Port of lib/eventCopy.ts.

public enum EventCopy {
  static func capitalize(_ value: String) -> String {
    guard let first = value.first else { return value }
    return first.uppercased() + value.dropFirst()
  }

  public static func durationMinutes(_ minutes: Double) -> String {
    guard minutes.isFinite, minutes > 0 else { return "" }
    let total = Int(jsRound(minutes))
    if total < 60 { return "\(total) min" }
    let h = total / 60
    let m = total % 60
    return m == 0 ? "\(h)h" : "\(h)h \(m)m"
  }

  static func sideWords(_ side: Side?) -> String {
    switch side {
    case .left: return "left"
    case .right: return "right"
    default: return "both sides"
    }
  }

  static func trailingMinutes(_ event: Event) -> String {
    guard let minutes = event.durationMinutes, minutes != 0 else { return "" }
    return " · \(jsNumber(minutes)) min"
  }

  public static func feedSummary(_ event: Event) -> String {
    if event.feedKind == .bottle {
      let milk = event.milk == .expressed ? "expressed" : "formula"
      return "\(event.amountMl.map(jsNumber) ?? "?") ml \(capitalize(milk))"
    }
    return "Breast \(sideWords(event.side))\(trailingMinutes(event))"
  }

  public static func nappySummary(_ event: Event) -> String {
    var bits: [String] = []
    if event.nappy == .wee || event.nappy == .both {
      bits.append("Wee \(capitalize(event.weeSize?.rawValue ?? ""))".trimmingCharacters(in: .whitespaces))
    }
    if event.nappy == .poo || event.nappy == .both {
      bits.append("Poo \(capitalize(event.pooSize?.rawValue ?? ""))".trimmingCharacters(in: .whitespaces))
    }
    return bits.isEmpty ? "Nappy" : bits.joined(separator: " · ")
  }

  public static func pumpSummary(_ event: Event) -> String {
    let amount = event.amountMl.map { " · \(jsNumber($0)) ml" } ?? ""
    return "\(capitalize(sideWords(event.side)))\(trailingMinutes(event))\(amount)"
  }

  public static func activitySummary(_ event: Event) -> String {
    let title = trimmed(event.title) ?? "Activity"
    let duration = event.durationMinutes.flatMap { $0 != 0 ? " · \(durationMinutes($0))" : nil } ?? ""
    return "\(title)\(duration)"
  }

  public static func kindLabel(_ event: Event, now: EpochMs) -> String {
    switch event.kind {
    case .feed: return "Feed"
    case .nappy: return "Nappy"
    case .weight: return "Weight"
    case .height: return "Height"
    case .sleep: return "Sleep"
    case .tummy: return "Tummy time"
    case .custom: return event.loggedAt > now ? "Upcoming" : "Event"
    case .pump: return "Pump"
    case .medicine: return "Medicine"
    case .potty: return "Potty"
    case .activity: return "Activity"
    }
  }

  public static func title(_ event: Event) -> String {
    switch event.kind {
    case .feed: return feedSummary(event)
    case .nappy, .potty: return nappySummary(event)
    case .weight: return event.weightGrams.map { Format.weight($0) } ?? "Weight"
    case .height: return event.heightCm.map { Format.height($0) } ?? "Height"
    case .sleep: return event.durationMinutes.map(durationMinutes) ?? "Sleep"
    case .tummy: return event.durationMinutes.map(durationMinutes) ?? "Tummy time"
    case .custom: return trimmed(event.title) ?? "Event"
    case .pump: return pumpSummary(event)
    case .medicine: return trimmed(event.title) ?? "Medicine"
    case .activity: return activitySummary(event)
    }
  }

  static func trimmed(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    return value
  }
}
