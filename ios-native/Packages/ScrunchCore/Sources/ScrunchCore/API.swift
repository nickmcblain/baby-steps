import Foundation

/// A typed reference to a Convex function plus its encoded arguments.
public struct ConvexCall<Result: Decodable>: Sendable {
  public let name: String
  public let args: [String: ConvexValue]

  public init(_ name: String, _ args: [String: ConvexValue] = [:]) {
    self.name = name
    self.args = args
  }

  /// Stable identity for SwiftUI `.task(id:)` so subscriptions restart when args change.
  public var key: String { name + ConvexValue.object(args).jsonString() }
}

/// Every Convex function the client calls. Mirrors `api.*` usage in the RN app.
public enum API {
  public enum users {
    public static func store() -> ConvexCall<User> { .init("users:store") }
    public static func current() -> ConvexCall<User?> { .init("users:current") }
  }

  public enum babies {
    public static func list() -> ConvexCall<[Baby]> { .init("babies:list") }

    public static func get(_ babyId: BabyID) -> ConvexCall<Baby> {
      .init("babies:get", convexArgs(["babyId": babyId]))
    }

    public static func create(
      name: String,
      dateOfBirth: Double,
      weightGrams: Double,
      heightCm: Double?,
      sex: Sex?,
      notes: String?
    ) -> ConvexCall<BabyID> {
      .init("babies:create", convexArgs([
        "name": name,
        "dateOfBirth": dateOfBirth,
        "weightGrams": weightGrams,
        "heightCm": heightCm,
        "sex": sex,
        "notes": notes,
        "careDataConsent": true,
      ]))
    }

    public static func update(
      babyId: BabyID,
      name: String,
      dateOfBirth: Double,
      notes: String?,
      sex: Sex?,
      deliveryType: DeliveryType?,
      gestationWeeks: Double?,
      feedingMode: FeedingMode?
    ) -> ConvexCall<ConvexNull> {
      .init("babies:update", convexArgs([
        "babyId": babyId,
        "name": name,
        "dateOfBirth": dateOfBirth,
        "notes": notes,
        "sex": sex,
        "deliveryType": deliveryType,
        "gestationWeeks": gestationWeeks,
        "feedingMode": feedingMode,
      ]))
    }

    public static func saveRoomTemp(babyId: BabyID, tempC: Double) -> ConvexCall<ConvexNull> {
      .init("babies:saveRoomTemp", convexArgs(["babyId": babyId, "tempC": tempC]))
    }

    public static func joinByCode(_ code: String) -> ConvexCall<BabyID> {
      .init("babies:joinByCode", convexArgs(["code": code]))
    }
  }

  public enum events {
    public static func dashboard(_ babyId: BabyID) -> ConvexCall<Dashboard> {
      .init("events:dashboard", convexArgs(["babyId": babyId]))
    }

    public static func daySummary(babyId: BabyID, dayStart: Double, dayEnd: Double) -> ConvexCall<DaySummary> {
      .init("events:daySummary", convexArgs(["babyId": babyId, "dayStart": dayStart, "dayEnd": dayEnd]))
    }

    public static func growthSeries(babyId: BabyID, kind: GrowthKind) -> ConvexCall<GrowthSeries> {
      .init("events:growthSeries", convexArgs(["babyId": babyId, "kind": kind]))
    }

    /// The live deployment only accepts `babyId` + `paginationOpts`; passing `kind` throws.
    public static func list(babyId: BabyID, numItems: Int) -> ConvexCall<EventPage> {
      .init("events:list", convexArgs([
        "babyId": babyId,
        "paginationOpts": ConvexValue.object([
          "numItems": .number(Double(numItems)),
          "cursor": .null,
        ]),
      ]))
    }

    public static func weekGrid(babyId: BabyID, weekStartMs: Double) -> ConvexCall<WeekGridData> {
      .init("events:weekGrid", convexArgs(["babyId": babyId, "weekStartMs": weekStartMs]))
    }

    public static func sleepPatterns(babyId: BabyID, days: Int, rangeEndMs: Double) -> ConvexCall<SleepPatterns> {
      .init("events:sleepPatterns", patternArgs(babyId, days, rangeEndMs))
    }

    public static func feedPatterns(babyId: BabyID, days: Int, rangeEndMs: Double) -> ConvexCall<FeedPatterns> {
      .init("events:feedPatterns", patternArgs(babyId, days, rangeEndMs))
    }

    public static func nappyPatterns(babyId: BabyID, days: Int, rangeEndMs: Double) -> ConvexCall<NappyPatterns> {
      .init("events:nappyPatterns", patternArgs(babyId, days, rangeEndMs))
    }

    public static func tummyPatterns(babyId: BabyID, days: Int, rangeEndMs: Double) -> ConvexCall<TummyPatterns> {
      .init("events:tummyPatterns", patternArgs(babyId, days, rangeEndMs))
    }

    private static func patternArgs(_ babyId: BabyID, _ days: Int, _ rangeEndMs: Double) -> [String: ConvexValue] {
      convexArgs(["babyId": babyId, "days": days, "rangeEndMs": rangeEndMs])
    }

    public static func logFeed(
      babyId: BabyID,
      loggedAt: Double,
      feedKind: FeedKind,
      side: Side? = nil,
      durationMinutes: Double? = nil,
      amountMl: Double? = nil,
      milk: Milk? = nil,
      note: String? = nil
    ) -> ConvexCall<EventID> {
      .init("events:logFeed", convexArgs([
        "babyId": babyId,
        "loggedAt": loggedAt,
        "feedKind": feedKind,
        "side": side,
        "durationMinutes": durationMinutes,
        "amountMl": amountMl,
        "milk": milk,
        "note": note,
      ]))
    }

    public static func logNappy(
      babyId: BabyID,
      loggedAt: Double,
      nappy: NappyKind,
      weeSize: NappySize? = nil,
      pooSize: NappySize? = nil,
      note: String? = nil
    ) -> ConvexCall<EventID> {
      .init("events:logNappy", nappyArgs(babyId, loggedAt, nappy, weeSize, pooSize, note))
    }

    public static func logPotty(
      babyId: BabyID,
      loggedAt: Double,
      nappy: NappyKind,
      weeSize: NappySize? = nil,
      pooSize: NappySize? = nil,
      note: String? = nil
    ) -> ConvexCall<EventID> {
      .init("events:logPotty", nappyArgs(babyId, loggedAt, nappy, weeSize, pooSize, note))
    }

    private static func nappyArgs(
      _ babyId: BabyID,
      _ loggedAt: Double,
      _ nappy: NappyKind,
      _ weeSize: NappySize?,
      _ pooSize: NappySize?,
      _ note: String?
    ) -> [String: ConvexValue] {
      convexArgs([
        "babyId": babyId,
        "loggedAt": loggedAt,
        "nappy": nappy,
        "weeSize": weeSize,
        "pooSize": pooSize,
        "note": note,
      ])
    }

    public static func logWeight(babyId: BabyID, loggedAt: Double, weightGrams: Double, note: String? = nil) -> ConvexCall<EventID> {
      .init("events:logWeight", convexArgs([
        "babyId": babyId, "loggedAt": loggedAt, "weightGrams": weightGrams, "note": note,
      ]))
    }

    public static func logHeight(babyId: BabyID, loggedAt: Double, heightCm: Double, note: String? = nil) -> ConvexCall<EventID> {
      .init("events:logHeight", convexArgs([
        "babyId": babyId, "loggedAt": loggedAt, "heightCm": heightCm, "note": note,
      ]))
    }

    public static func logSleep(babyId: BabyID, loggedAt: Double, durationMinutes: Double, note: String? = nil) -> ConvexCall<EventID> {
      .init("events:logSleep", convexArgs([
        "babyId": babyId, "loggedAt": loggedAt, "durationMinutes": durationMinutes, "note": note,
      ]))
    }

    public static func logTummy(babyId: BabyID, loggedAt: Double, durationMinutes: Double, note: String? = nil) -> ConvexCall<EventID> {
      .init("events:logTummy", convexArgs([
        "babyId": babyId, "loggedAt": loggedAt, "durationMinutes": durationMinutes, "note": note,
      ]))
    }

    public static func logPump(
      babyId: BabyID,
      loggedAt: Double,
      side: Side,
      durationMinutes: Double,
      amountMl: Double? = nil,
      note: String? = nil
    ) -> ConvexCall<EventID> {
      .init("events:logPump", convexArgs([
        "babyId": babyId,
        "loggedAt": loggedAt,
        "side": side,
        "durationMinutes": durationMinutes,
        "amountMl": amountMl,
        "note": note,
      ]))
    }

    public static func logMedicine(babyId: BabyID, loggedAt: Double, title: String, note: String? = nil) -> ConvexCall<EventID> {
      .init("events:logMedicine", convexArgs([
        "babyId": babyId, "loggedAt": loggedAt, "title": title, "note": note,
      ]))
    }

    public static func logActivity(
      babyId: BabyID,
      loggedAt: Double,
      title: String,
      durationMinutes: Double? = nil,
      note: String? = nil
    ) -> ConvexCall<EventID> {
      .init("events:logActivity", convexArgs([
        "babyId": babyId,
        "loggedAt": loggedAt,
        "title": title,
        "durationMinutes": durationMinutes,
        "note": note,
      ]))
    }

    public static func logCustom(babyId: BabyID, loggedAt: Double, title: String, note: String? = nil) -> ConvexCall<EventID> {
      .init("events:logCustom", convexArgs([
        "babyId": babyId, "loggedAt": loggedAt, "title": title, "note": note,
      ]))
    }

    public static func remove(_ eventId: EventID) -> ConvexCall<ConvexNull> {
      .init("events:remove", convexArgs(["eventId": eventId]))
    }

    public static func moveLoggedAt(_ eventId: EventID, to loggedAt: EpochMs) -> ConvexCall<ConvexNull> {
      .init("events:moveLoggedAt", convexArgs(["eventId": eventId, "loggedAt": loggedAt]))
    }
  }

  public enum chat {
    public static func ensureThread(_ babyId: BabyID) -> ConvexCall<ThreadID> {
      .init("chat:ensureThread", convexArgs(["babyId": babyId]))
    }

    public static func createThread(_ babyId: BabyID) -> ConvexCall<ThreadID> {
      .init("chat:createThread", convexArgs(["babyId": babyId]))
    }

    public static func listThreads(_ babyId: BabyID) -> ConvexCall<[ChatThread]> {
      .init("chat:listThreads", convexArgs(["babyId": babyId]))
    }

    public static func listMessages(_ threadId: ThreadID) -> ConvexCall<[ChatMessage]> {
      .init("chat:listMessages", convexArgs(["threadId": threadId]))
    }
  }

  public enum chatAgent {
    public static func ask(babyId: BabyID, threadId: ThreadID, message: String) -> ConvexCall<AskReply> {
      .init("chatAgent:ask", convexArgs(["babyId": babyId, "threadId": threadId, "message": message]))
    }
  }

  public enum subscriptions {
    /// The user's stable UUID for StoreKit's appAccountToken.
    public static func accountToken() -> ConvexCall<String> { .init("subscriptions:accountToken") }
  }

  public enum appStore {
    public static func syncTransaction(_ signedTransaction: String) -> ConvexCall<Bool> {
      .init("appStore:syncTransaction", convexArgs(["signedTransaction": signedTransaction]))
    }
  }

  public enum allowance {
    public static func mine() -> ConvexCall<AllowanceResponse> { .init("allowance:mine") }
  }

  public enum voiceLog {
    /// The action rejects payloads above roughly 900k base64 characters.
    public static let maxAudioBase64Length = 900_000

    public static func logFromAudio(babyId: BabyID, audioBase64: String) -> ConvexCall<VoiceLogResult> {
      .init("voiceLog:logFromAudio", convexArgs([
        "babyId": babyId, "audioBase64": audioBase64, "format": "m4a",
      ]))
    }
  }
}
