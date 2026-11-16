import Foundation

/// Health-system wording that differs by country: emergency numbers, who to ask, whose guidance we
/// summarise and which growth charts we plot. Version 1.0 ships in the UK only. Adding the US or
/// Australia means a new case here (999 → 911 / 000, NHS 111 → nurse line / Healthdirect, health
/// visitor → paediatrician / child health nurse, UK-WHO → CDC-WHO), not edits across the app.
public enum HealthRegion: String, Sendable {
  case uk

  /// Follows where the app is sold, not the device language, so a UK parent with a US-English
  /// phone still gets NHS guidance.
  public static let current: HealthRegion = .uk

  public var emergencyTitle: String {
    switch self {
    case .uk: return String(localized: "Seek urgent help", bundle: .module)
    }
  }

  public var emergencyBody: String {
    switch self {
    case .uk:
      return String(
        localized: "If your baby is not breathing normally, is unresponsive, blue/grey, or having a seizure, call 999 now.",
        bundle: .module
      )
    }
  }

  public var askDisclaimer: String {
    switch self {
    case .uk:
      return String(
        localized: "Scrunch is not a medical or healthcare service. Guidance only — not diagnosis, clinical advice, or triage. Emergencies: call 999. Urgent advice: NHS 111 or your midwife. Scrunch is independent and not affiliated with the NHS or The Lullaby Trust; it summarises their public guidance.",
        bundle: .module
      )
    }
  }

  public var askEntrySubtitle: String {
    switch self {
    case .uk: return String(localized: "Answers from NHS and Lullaby Trust guidance", bundle: .module)
    }
  }

  public var askNoSourceNote: String {
    switch self {
    case .uk:
      return String(
        localized: "General guidance. No specific NHS or Lullaby Trust page matched, so check nhs.uk or ask your health visitor.",
        bundle: .module
      )
    }
  }

  public var askHelpLine: String {
    switch self {
    case .uk: return String(localized: "Worried? Call your GP or NHS 111. Emergency: call 999.", bundle: .module)
    }
  }

  /// Short attribution after a sleep-shape caption.
  public var sleepGuidanceSource: String {
    switch self {
    case .uk: return String(localized: "NHS, not a timetable.", bundle: .module)
    }
  }

  public var growthChartSource: String {
    switch self {
    case .uk: return String(localized: "UK Red Book centiles (WHO / UK-WHO standards)", bundle: .module)
    }
  }

  public var growthOutsideRangeCaution: String {
    switch self {
    case .uk:
      return String(
        localized: "Outside usual UK chart range — check with your health visitor or GP. This is not medical advice.",
        bundle: .module
      )
    }
  }
}
