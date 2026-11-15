import Foundation

// Codable mirrors of convex/schema.ts and the return validators in convex/.
// Every Convex number is float64, so every number here is a Double.

public typealias BabyID = String
public typealias EventID = String
public typealias ThreadID = String

// MARK: - Enums

public enum EventKind: String, Codable, CaseIterable, Sendable, ConvexRepresentable {
  case feed, nappy, weight, height, sleep, tummy, custom, pump, medicine, potty, activity
}

public enum FeedKind: String, Codable, CaseIterable, Sendable, ConvexRepresentable {
  case breast, bottle
}

public enum Side: String, Codable, CaseIterable, Sendable, ConvexRepresentable {
  case left, right, both
}

public enum Milk: String, Codable, CaseIterable, Sendable, ConvexRepresentable {
  case formula, expressed
}

public enum NappyKind: String, Codable, CaseIterable, Sendable, ConvexRepresentable {
  case wee, poo, both
}

public enum NappySize: String, Codable, CaseIterable, Sendable, ConvexRepresentable {
  case small, medium, large
}

public enum Sex: String, Codable, CaseIterable, Sendable, ConvexRepresentable {
  case boy, girl
}

public enum DeliveryType: String, Codable, CaseIterable, Sendable, ConvexRepresentable {
  case vaginal
  case cSection = "c_section"
}

public enum FeedingMode: String, Codable, CaseIterable, Sendable, ConvexRepresentable {
  case breast, bottle, mixed
}

public enum ChatRole: String, Codable, Sendable {
  case user, assistant, system
}

public enum GrowthKind: String, Codable, Sendable, ConvexRepresentable {
  case weight, height
}

public enum WeekMarkerKind: String, Codable, CaseIterable, Sendable {
  case feed, nappy, weight, height, custom, pump, medicine, potty, activity
}

// MARK: - Documents

public struct User: Decodable, Equatable, Sendable, Identifiable {
  public let id: String
  public let creationTime: Double
  public let tokenIdentifier: String
  public let name: String
  public let email: String?

  enum CodingKeys: String, CodingKey {
    case id = "_id"
    case creationTime = "_creationTime"
    case tokenIdentifier, name, email
  }
}

public struct Baby: Decodable, Equatable, Hashable, Sendable, Identifiable {
  public let id: BabyID
  public let creationTime: Double
  public let name: String
  /// UTC midnight of the birth date, in ms.
  public let dateOfBirth: Double
  public let weightGrams: Double
  public let heightCm: Double?
  public let sex: Sex?
  public let notes: String?
  /// Only sent to carers with an active subscription; nil until a subscriber creates one.
  public let inviteCode: String?
  public let lastRoomTempC: Double?
  public let deliveryType: DeliveryType?
  public let gestationWeeks: Double?
  public let feedingMode: FeedingMode?
  public let nightBedMin: Double?
  public let nightWakeMin: Double?
  public let createdBy: String
  public let careDataConsentAt: Double?
  public let careDataConsentVersion: String?

  enum CodingKeys: String, CodingKey {
    case id = "_id"
    case creationTime = "_creationTime"
    case name, dateOfBirth, weightGrams, heightCm, sex, notes, inviteCode, lastRoomTempC
    case deliveryType, gestationWeeks, feedingMode, nightBedMin, nightWakeMin, createdBy
    case careDataConsentAt, careDataConsentVersion
  }

  public init(
    id: BabyID,
    creationTime: Double = 0,
    name: String,
    dateOfBirth: Double,
    weightGrams: Double,
    heightCm: Double? = nil,
    sex: Sex? = nil,
    notes: String? = nil,
    inviteCode: String? = "ABC234",
    lastRoomTempC: Double? = nil,
    deliveryType: DeliveryType? = nil,
    gestationWeeks: Double? = nil,
    feedingMode: FeedingMode? = nil,
    nightBedMin: Double? = nil,
    nightWakeMin: Double? = nil,
    createdBy: String = "",
    careDataConsentAt: Double? = nil,
    careDataConsentVersion: String? = nil
  ) {
    self.id = id
    self.creationTime = creationTime
    self.name = name
    self.dateOfBirth = dateOfBirth
    self.weightGrams = weightGrams
    self.heightCm = heightCm
    self.sex = sex
    self.notes = notes
    self.inviteCode = inviteCode
    self.lastRoomTempC = lastRoomTempC
    self.deliveryType = deliveryType
    self.gestationWeeks = gestationWeeks
    self.feedingMode = feedingMode
    self.nightBedMin = nightBedMin
    self.nightWakeMin = nightWakeMin
    self.createdBy = createdBy
    self.careDataConsentAt = careDataConsentAt
    self.careDataConsentVersion = careDataConsentVersion
  }

  /// The parent-set night, when both ends are present.
  public var nightWindow: NightWindow? {
    guard let nightBedMin, let nightWakeMin else { return nil }
    return NightWindow(bedMin: nightBedMin, wakeMin: nightWakeMin)
  }
}

/// A logged event. Decodes both full documents and `daySummary`'s trimmed day events
/// (which omit `babyId`, `createdBy` and `_creationTime`).
public struct Event: Decodable, Equatable, Hashable, Sendable, Identifiable {
  public let id: EventID
  public let creationTime: Double?
  public let babyId: BabyID?
  public let createdBy: String?
  public let loggedAt: Double
  public let kind: EventKind
  public let feedKind: FeedKind?
  public let side: Side?
  public let durationMinutes: Double?
  public let amountMl: Double?
  public let milk: Milk?
  public let nappy: NappyKind?
  public let weeSize: NappySize?
  public let pooSize: NappySize?
  public let weightGrams: Double?
  public let heightCm: Double?
  public let title: String?
  public let note: String?

  enum CodingKeys: String, CodingKey {
    case id = "_id"
    case creationTime = "_creationTime"
    case babyId, createdBy, loggedAt, kind, feedKind, side, durationMinutes, amountMl, milk
    case nappy, weeSize, pooSize, weightGrams, heightCm, title, note
  }

  public init(
    id: EventID = UUID().uuidString,
    loggedAt: Double,
    kind: EventKind,
    feedKind: FeedKind? = nil,
    side: Side? = nil,
    durationMinutes: Double? = nil,
    amountMl: Double? = nil,
    milk: Milk? = nil,
    nappy: NappyKind? = nil,
    weeSize: NappySize? = nil,
    pooSize: NappySize? = nil,
    weightGrams: Double? = nil,
    heightCm: Double? = nil,
    title: String? = nil,
    note: String? = nil
  ) {
    self.id = id
    self.creationTime = nil
    self.babyId = nil
    self.createdBy = nil
    self.loggedAt = loggedAt
    self.kind = kind
    self.feedKind = feedKind
    self.side = side
    self.durationMinutes = durationMinutes
    self.amountMl = amountMl
    self.milk = milk
    self.nappy = nappy
    self.weeSize = weeSize
    self.pooSize = pooSize
    self.weightGrams = weightGrams
    self.heightCm = heightCm
    self.title = title
    self.note = note
  }
}

// MARK: - Query results

public struct Dashboard: Decodable, Equatable, Sendable {
  public let baby: Baby
  public let lastFeed: Event?
  public let lastNappy: Event?
  public let lastSleep: Event?
  public let lastTummy: Event?
}

public struct DaySummary: Decodable, Equatable, Sendable {
  public let baby: Baby
  public let sleepMinutes: Double
  public let feedCount: Double
  public let nappyCount: Double
  public let tummyMinutes: Double
  public let lastSleepEndMs: Double?
  public let events: [Event]
  public let recentLoggedAts: [Double]
}

public struct GrowthPoint: Decodable, Equatable, Sendable {
  public let at: Double
  /// kg for weight, cm for height.
  public let value: Double

  public init(at: Double, value: Double) {
    self.at = at
    self.value = value
  }
}

public struct GrowthSeries: Decodable, Equatable, Sendable {
  public let baby: Baby
  public let points: [GrowthPoint]
}

public struct EventPage: Decodable, Equatable, Sendable {
  public let page: [Event]
  public let isDone: Bool
  public let continueCursor: String
}

public struct WeekSegment: Decodable, Equatable, Sendable {
  public let eventId: EventID
  public let startMs: Double
  public let endMs: Double
}

public struct WeekMarker: Decodable, Equatable, Sendable {
  public let kind: WeekMarkerKind
  public let eventId: EventID
  public let atMs: Double
}

public struct WeekGridData: Decodable, Equatable, Sendable {
  public let weekStartMs: Double
  public let sleeps: [WeekSegment]
  public let tummies: [WeekSegment]
  public let markers: [WeekMarker]
}

public struct PatternItem: Decodable, Equatable, Sendable {
  public let startMs: Double
  public let endMs: Double
  public let durationMinutes: Double

  public init(startMs: Double, endMs: Double, durationMinutes: Double) {
    self.startMs = startMs
    self.endMs = endMs
    self.durationMinutes = durationMinutes
  }
}

public struct SleepPatterns: Decodable, Equatable, Sendable {
  public struct Stats: Decodable, Equatable, Sendable {
    public let avgSleepMinutesPerDay: Double
    public let avgSessionsPerDay: Double
  }
  public let sleeps: [PatternItem]
  public let stats: Stats
}

public struct FeedPatterns: Decodable, Equatable, Sendable {
  public struct Stats: Decodable, Equatable, Sendable {
    public let avgFeedMinutesPerDay: Double
    public let avgSessionsPerDay: Double
  }
  public let feeds: [PatternItem]
  public let stats: Stats
}

public struct NappyPatterns: Decodable, Equatable, Sendable {
  public struct Stats: Decodable, Equatable, Sendable {
    public let avgSessionsPerDay: Double
    public let weeCount: Double
    public let pooCount: Double
  }
  public let nappies: [PatternItem]
  public let stats: Stats
}

public struct TummyPatterns: Decodable, Equatable, Sendable {
  public struct Stats: Decodable, Equatable, Sendable {
    public let avgTummyMinutesPerDay: Double
    public let avgSessionsPerDay: Double
  }
  public let tummies: [PatternItem]
  public let stats: Stats
}

public struct Citation: Decodable, Equatable, Hashable, Sendable {
  public let title: String
  public let url: String?

  public init(title: String, url: String?) {
    self.title = title
    self.url = url
  }
}

public struct ChatThread: Decodable, Equatable, Sendable, Identifiable {
  public let id: ThreadID
  public let creationTime: Double
  public let babyId: BabyID
  public let createdBy: String
  public let title: String?
  public let updatedAt: Double

  enum CodingKeys: String, CodingKey {
    case id = "_id"
    case creationTime = "_creationTime"
    case babyId, createdBy, title, updatedAt
  }
}

public struct ChatMessage: Decodable, Equatable, Sendable, Identifiable {
  public let id: String
  public let creationTime: Double
  public let threadId: ThreadID
  public let babyId: BabyID
  public let role: ChatRole
  public let content: String
  public let citations: [Citation]?
  public let createdAt: Double

  enum CodingKeys: String, CodingKey {
    case id = "_id"
    case creationTime = "_creationTime"
    case threadId, babyId, role, content, citations, createdAt
  }
}

public struct AskReply: Decodable, Equatable, Sendable {
  public let content: String
  public let citations: [Citation]
}

public struct VoiceLogResult: Decodable, Equatable, Sendable {
  public let transcript: String
  public let confirmation: String
  /// `"ask"` when the speech was a question rather than a log.
  public let handoff: String?
}
