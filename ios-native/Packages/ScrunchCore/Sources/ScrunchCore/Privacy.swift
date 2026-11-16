import Foundation

// Account deletion, care-log export and the AI disclosure shown before Ask and Speak.

public struct DeletedData: Decodable, Equatable, Sendable {
  public let deletedBabies: Double
  public let leftSharedBabies: Double
  /// False when the server has no Clerk secret; the app then deletes the Clerk user itself.
  public let signInDeleted: Bool
}

public struct CareLog: Decodable, Equatable, Sendable {
  public let baby: Baby
  public let events: [Event]
  public let truncated: Bool

  public init(baby: Baby, events: [Event], truncated: Bool = false) {
    self.baby = baby
    self.events = events
    self.truncated = truncated
  }
}

extension API {
  public enum account {
    public static func deleteAccount() -> ConvexCall<DeletedData> { .init("account:deleteAccount") }
  }

  public enum careExport {
    public static func babyCareLog(_ babyId: BabyID) -> ConvexCall<CareLog> {
      .init("careExport:babyCareLog", convexArgs(["babyId": babyId]))
    }
  }
}

// MARK: - Export

public enum CareExport {
  public struct Row: Equatable, Sendable {
    public let date: String
    public let time: String
    public let type: String
    public let details: String
    public let durationMinutes: String
    public let amountMl: String
    public let weightKg: String
    public let lengthCm: String
    public let note: String
  }

  public struct Day: Equatable, Sendable {
    public let heading: String
    public let rows: [Row]
  }

  public static let csvHeader = [
    "Date", "Time", "Type", "Details", "Duration (min)", "Amount (ml)", "Weight (kg)", "Length (cm)", "Note",
  ]

  public static let pdfFootnote =
    "Logged by parents and carers in the Scrunch app. This is not a medical record."

  public static func rows(_ log: CareLog, timeZone: TimeZone, now: EpochMs) -> [Row] {
    let date = formatter("dd/MM/yyyy", timeZone)
    let time = formatter("HH:mm", timeZone)
    return log.events.sorted { $0.loggedAt < $1.loggedAt }.map { event in
      let at = Date(timeIntervalSince1970: event.loggedAt / 1000)
      return Row(
        date: date.string(from: at),
        time: time.string(from: at),
        type: EventCopy.kindLabel(event, now: now),
        details: EventCopy.title(event),
        durationMinutes: event.durationMinutes.map(jsNumber) ?? "",
        amountMl: event.amountMl.map(jsNumber) ?? "",
        weightKg: event.weightGrams.map { jsNumber(($0 / 10).rounded() / 100) } ?? "",
        lengthCm: event.heightCm.map(jsNumber) ?? "",
        note: EventCopy.trimmed(event.note) ?? ""
      )
    }
  }

  /// RFC 4180 CSV. Cells that a spreadsheet would run as a formula get a leading quote.
  public static func csv(_ log: CareLog, timeZone: TimeZone, now: EpochMs) -> String {
    let lines = [csvHeader] + rows(log, timeZone: timeZone, now: now).map { row in
      [row.date, row.time, row.type, row.details, row.durationMinutes, row.amountMl, row.weightKg, row.lengthCm, row.note]
    }
    return lines.map { $0.map(csvCell).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
  }

  static func csvCell(_ raw: String) -> String {
    var value = raw
    if let first = value.first, "=+-@\t\r".contains(first), Double(value) == nil {
      value = "'" + value
    }
    if value.contains(where: { ",\"\n\r".contains($0) }) {
      return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    return value
  }

  /// Rows grouped by local day, newest day first, for the PDF.
  public static func days(_ log: CareLog, timeZone: TimeZone, now: EpochMs) -> [Day] {
    let heading = formatter("EEEE d MMMM yyyy", timeZone)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let sorted = log.events.sorted { $0.loggedAt < $1.loggedAt }
    let allRows = rows(log, timeZone: timeZone, now: now)
    var days: [Day] = []
    var current: (start: Date, rows: [Row])?
    for (event, row) in zip(sorted, allRows) {
      let start = calendar.startOfDay(for: Date(timeIntervalSince1970: event.loggedAt / 1000))
      if current?.start != start {
        if let current { days.append(Day(heading: heading.string(from: current.start), rows: current.rows)) }
        current = (start, [])
      }
      current?.rows.append(row)
    }
    if let current { days.append(Day(heading: heading.string(from: current.start), rows: current.rows)) }
    return days.reversed()
  }

  public static func fileName(babyName: String, now: EpochMs, timeZone: TimeZone, ext: String) -> String {
    let safe = babyName.unicodeScalars
      .map { CharacterSet.alphanumerics.contains($0) ? String($0) : "-" }
      .joined()
      .split(separator: "-")
      .joined(separator: "-")
    let stamp = formatter("yyyy-MM-dd", timeZone).string(from: Date(timeIntervalSince1970: now / 1000))
    return "Scrunch-\(safe.isEmpty ? "baby" : safe)-care-log-\(stamp).\(ext)"
  }

  public static func subtitle(_ log: CareLog, timeZone: TimeZone, now: EpochMs) -> String {
    let day = formatter("d MMMM yyyy", timeZone)
    let born = day.string(from: Date(timeIntervalSince1970: log.baby.dateOfBirth / 1000))
    let exported = day.string(from: Date(timeIntervalSince1970: now / 1000))
    let count = log.events.count
    return "Born \(born) · \(count) \(count == 1 ? "entry" : "entries") · Exported \(exported)"
  }

  static func formatter(_ format: String, _ timeZone: TimeZone) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_GB")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = timeZone
    formatter.dateFormat = format
    return formatter
  }
}

// MARK: - AI disclosure

/// Copy for "About Ask and Speak (AI)". Keep it in step with `convex/chatAgent.ts`
/// and `convex/voiceLog.ts`; bump `consentVersion` when what is sent changes.
public enum AIDisclosure {
  public static let consentVersion = "ai-v1"
  public static let consentKey = "scrunch.aiConsentVersion"

  public static func hasConsented(_ stored: String?) -> Bool { stored == consentVersion }

  public static let title = "About Ask and Speak (AI)"

  public static let summary =
    "Ask and Speak use an AI model. Your questions and your baby's details leave your phone so the model can answer."

  public static let provider =
    "Answers come from Google's Gemini model, reached through OpenRouter, an AI service based in the US. Speak turns your voice into text with OpenAI's Whisper model, also through OpenRouter."

  public static let sent = [
    "What you type or say to Ask, and the earlier messages in that chat",
    "Your baby's name, age, date of birth, weight, length, birth details, feeding type, room temperature and notes",
    "Recent feeds and nappies, and any facts Ask has remembered from past chats",
    "For Speak: a short recording of your voice, sent for transcription",
  ]

  public static let notSent = [
    "Your email address, your name or your sign-in details",
    "Anything when you're not using Ask or Speak",
  ]

  public static let handling =
    "Scrunch sends this from our server, not from your phone. OpenRouter and the model providers process it to produce an answer under their own terms. Scrunch keeps your Ask chats so you can read them later; voice recordings aren't kept. We never use your data for advertising."

  public static let medical =
    "Ask gives general guidance, not medical advice. In an emergency call 999. For urgent advice call NHS 111 or your midwife."

  public static let consent =
    "I understand that Ask and Speak send the details above to an AI service so it can answer."
}
