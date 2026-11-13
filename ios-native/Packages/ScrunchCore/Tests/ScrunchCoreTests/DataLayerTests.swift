import XCTest
@testable import ScrunchCore

final class ConvexValueTests: XCTestCase {
  func testNumbersAreFloat64JSONNotInt64() {
    // Int must not become a `$integer` — v.number() rejects int64.
    XCTAssertEqual(7.convexValue, .number(7))
    XCTAssertEqual(ConvexValue.number(7).jsonString(), "7")
    XCTAssertEqual(ConvexValue.number(1_763_000_000_000).jsonString(), "1763000000000")
    XCTAssertEqual(ConvexValue.number(2.5).jsonString(), "2.5")
    XCTAssertEqual(ConvexValue.number(-0.5).jsonString(), "-0.5")
    XCTAssertEqual(ConvexValue.number(.nan).jsonString().hasPrefix("{\"$float\":"), true)
  }

  func testStringsAreEscaped() {
    XCTAssertEqual(ConvexValue.string("a\"b\\c\nd").jsonString(), #""a\"b\\c\nd""#)
    XCTAssertEqual(ConvexValue.string("Wee · poo ☺").jsonString(), "\"Wee · poo ☺\"")
  }

  func testObjectsAreSortedAndNullIsExplicit() {
    let value = ConvexValue.object(["b": .number(1), "a": .null, "c": .array([.bool(true), .string("x")])])
    XCTAssertEqual(value.jsonString(), #"{"a":null,"b":1,"c":[true,"x"]}"#)
  }

  func testArgsOmitNilOptionals() {
    let note: String? = nil
    let args = convexArgs(["babyId": "b1", "note": note, "amountMl": 120.0])
    XCTAssertEqual(Set(args.keys), ["babyId", "amountMl"])
  }

  func testOutputParsesAsJSON() throws {
    let call = API.events.logFeed(babyId: "b1", loggedAt: 1_763_000_000_000, feedKind: .bottle, amountMl: 120, milk: .formula)
    let json = ConvexValue.object(call.args).jsonString()
    let parsed = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
    XCTAssertEqual(parsed["feedKind"] as? String, "bottle")
    XCTAssertEqual(parsed["amountMl"] as? Double, 120)
    XCTAssertNil(parsed["side"])
  }
}

final class APITests: XCTestCase {
  func testFunctionNamesAndArgs() {
    XCTAssertEqual(API.babies.list().name, "babies:list")
    XCTAssertEqual(API.babies.list().args, [:])

    let create = API.babies.create(name: "Nico", dateOfBirth: 0, weightGrams: 3400, heightCm: nil, sex: .boy, notes: nil)
    XCTAssertEqual(create.name, "babies:create")
    XCTAssertEqual(create.args, [
      "name": .string("Nico"), "dateOfBirth": .number(0), "weightGrams": .number(3400),
      "sex": .string("boy"), "careDataConsent": .bool(true),
    ])

    let update = API.babies.update(
      babyId: "b1", name: "Nico", dateOfBirth: 0, notes: nil, sex: nil,
      deliveryType: .cSection, gestationWeeks: 39, feedingMode: .mixed
    )
    XCTAssertEqual(update.args["deliveryType"], .string("c_section"))
    XCTAssertEqual(update.args["gestationWeeks"], .number(39))
    XCTAssertNil(update.args["sex"])
  }

  func testEventsListOnlySendsBabyIdAndPagination() {
    let call = API.events.list(babyId: "b1", numItems: 40)
    XCTAssertEqual(call.name, "events:list")
    XCTAssertEqual(Set(call.args.keys), ["babyId", "paginationOpts"])
    XCTAssertEqual(call.args["paginationOpts"], .object(["numItems": .number(40), "cursor": .null]))
  }

  func testPatternDaysAreNumbers() {
    XCTAssertEqual(API.events.sleepPatterns(babyId: "b1", days: 14, rangeEndMs: 5).args["days"], .number(14))
  }

  func testEveryClientFunction() {
    let names = [
      API.users.store().name, API.users.current().name,
      API.babies.list().name, API.babies.get("b").name,
      API.babies.create(name: "", dateOfBirth: 0, weightGrams: 0, heightCm: nil, sex: nil, notes: nil).name,
      API.babies.update(babyId: "b", name: "", dateOfBirth: 0, notes: nil, sex: nil, deliveryType: nil, gestationWeeks: nil, feedingMode: nil).name,
      API.babies.saveRoomTemp(babyId: "b", tempC: 18).name, API.babies.joinByCode("X").name,
      API.events.dashboard("b").name, API.events.daySummary(babyId: "b", dayStart: 0, dayEnd: 1).name,
      API.events.growthSeries(babyId: "b", kind: .weight).name, API.events.list(babyId: "b", numItems: 1).name,
      API.events.weekGrid(babyId: "b", weekStartMs: 0).name,
      API.events.sleepPatterns(babyId: "b", days: 7, rangeEndMs: 0).name,
      API.events.feedPatterns(babyId: "b", days: 7, rangeEndMs: 0).name,
      API.events.nappyPatterns(babyId: "b", days: 7, rangeEndMs: 0).name,
      API.events.tummyPatterns(babyId: "b", days: 7, rangeEndMs: 0).name,
      API.events.logFeed(babyId: "b", loggedAt: 0, feedKind: .breast).name,
      API.events.logNappy(babyId: "b", loggedAt: 0, nappy: .wee).name,
      API.events.logPotty(babyId: "b", loggedAt: 0, nappy: .wee).name,
      API.events.logWeight(babyId: "b", loggedAt: 0, weightGrams: 1).name,
      API.events.logHeight(babyId: "b", loggedAt: 0, heightCm: 1).name,
      API.events.logSleep(babyId: "b", loggedAt: 0, durationMinutes: 1).name,
      API.events.logTummy(babyId: "b", loggedAt: 0, durationMinutes: 1).name,
      API.events.logPump(babyId: "b", loggedAt: 0, side: .left, durationMinutes: 1).name,
      API.events.logMedicine(babyId: "b", loggedAt: 0, title: "").name,
      API.events.logActivity(babyId: "b", loggedAt: 0, title: "").name,
      API.events.logCustom(babyId: "b", loggedAt: 0, title: "").name,
      API.events.remove("e").name,
      API.chat.ensureThread("b").name, API.chat.createThread("b").name,
      API.chat.listThreads("b").name, API.chat.listMessages("t").name,
      API.chatAgent.ask(babyId: "b", threadId: "t", message: "").name,
      API.voiceLog.logFromAudio(babyId: "b", audioBase64: "").name,
    ]
    XCTAssertEqual(names.count, 35)
    XCTAssertEqual(Set(names).count, 35)
    XCTAssertTrue(names.allSatisfy { $0.contains(":") })
  }
}

final class ModelDecodingTests: XCTestCase {
  let babyJSON = """
  {"_id":"k1","_creationTime":1763000000000.5,"name":"Nico","dateOfBirth":1767398400000,
   "weightGrams":3400.0,"inviteCode":"ABC234","createdBy":"u1","sex":"boy",
   "deliveryType":"c_section","feedingMode":"mixed","nightBedMin":1140,"nightWakeMin":420}
  """

  func testBabyDecodesFloatNumbersAndEnums() throws {
    let baby = try JSONDecoder().decode(Baby.self, from: Data(babyJSON.utf8))
    XCTAssertEqual(baby.weightGrams, 3400)
    XCTAssertEqual(baby.deliveryType, .cSection)
    XCTAssertEqual(baby.nightWindow, NightWindow(bedMin: 1140, wakeMin: 420))
    XCTAssertNil(baby.heightCm)
  }

  func testDashboardWithNulls() throws {
    let json = """
    {"baby":\(babyJSON),"lastFeed":{"_id":"e1","_creationTime":1,"babyId":"k1","createdBy":"u1",
     "loggedAt":1763000000000,"kind":"feed","feedKind":"breast","side":"left","durationMinutes":12.0},
     "lastNappy":null,"lastSleep":null,"lastTummy":null}
    """
    let dash = try JSONDecoder().decode(Dashboard.self, from: Data(json.utf8))
    XCTAssertEqual(dash.lastFeed?.side, .left)
    XCTAssertEqual(dash.lastFeed?.durationMinutes, 12)
    XCTAssertNil(dash.lastNappy)
  }

  func testDaySummaryTrimmedEvents() throws {
    let json = """
    {"baby":\(babyJSON),"sleepMinutes":804,"feedCount":7,"nappyCount":5,"tummyMinutes":12.5,
     "lastSleepEndMs":null,"events":[{"_id":"e2","kind":"nappy","loggedAt":5,"nappy":"both","weeSize":"small","pooSize":"large"}],
     "recentLoggedAts":[1,2,3]}
    """
    let summary = try JSONDecoder().decode(DaySummary.self, from: Data(json.utf8))
    XCTAssertEqual(summary.events.first?.pooSize, .large)
    XCTAssertNil(summary.events.first?.babyId)
    XCTAssertNil(summary.lastSleepEndMs)
  }

  func testPageWeekGridAndChat() throws {
    let page = try JSONDecoder().decode(EventPage.self, from: Data("""
    {"page":[],"isDone":false,"continueCursor":"abc","splitCursor":null,"pageStatus":null}
    """.utf8))
    XCTAssertFalse(page.isDone)

    let grid = try JSONDecoder().decode(WeekGridData.self, from: Data("""
    {"weekStartMs":0,"sleeps":[{"kind":"sleep","eventId":"e","startMs":1,"endMs":2}],"tummies":[],
     "markers":[{"kind":"medicine","eventId":"e","atMs":3}]}
    """.utf8))
    XCTAssertEqual(grid.markers.first?.kind, .medicine)

    let messages = try JSONDecoder().decode([ChatMessage].self, from: Data("""
    [{"_id":"m","_creationTime":1,"threadId":"t","babyId":"b","role":"assistant","content":"Hi",
      "citations":[{"title":"NHS"},{"title":"Lullaby Trust","url":"https://www.lullabytrust.org.uk"}],"createdAt":1}]
    """.utf8))
    XCTAssertEqual(messages.first?.citations?.count, 2)

    let voice = try JSONDecoder().decode(VoiceLogResult.self, from: Data(#"{"transcript":"t","confirmation":"c","handoff":null}"#.utf8))
    XCTAssertNil(voice.handoff)
    _ = try JSONDecoder().decode(ConvexNull.self, from: Data("null".utf8))
  }
}

final class AskAndTimelineTests: XCTestCase {
  func testEmergency() {
    XCTAssertTrue(AskSafety.isEmergency("He's NOT BREATHING properly"))
    XCTAssertTrue(AskSafety.isEmergency("possible seizure?"))
    XCTAssertFalse(AskSafety.isEmergency("seizures history")) // word boundary, as the RN regex
    XCTAssertFalse(AskSafety.isEmergency("How long should naps be?"))
  }

  func testMarkdownBlocks() {
    let blocks = MarkdownBlocks.parse("""
    ## Safe sleep
    Put them on their **back**
    in a clear cot.

    - Firm mattress
    * No pillows
    1. Room 16–20°C
    """)
    XCTAssertEqual(blocks, [
      .heading("Safe sleep"),
      .paragraph("Put them on their **back** in a clear cot."),
      .bullet("Firm mattress"),
      .bullet("No pillows"),
      .numbered(1, "Room 16–20°C"),
    ])
  }

  func testInviteCode() {
    XCTAssertEqual(InviteCode.sanitize("ab-c1o0 2z9q7k"), "ABC2Z9")
    XCTAssertEqual(InviteCode.sanitize("i l o 0 1"), "L")
    XCTAssertEqual(jsToFixed(1.25, 1), "1.3")
    XCTAssertEqual(jsToFixed(0.05, 1), "0.1")
  }

  func testTimelineSectionsPutUpcomingFirst() {
    let now = at(2026, 7, 20, 10)
    let events = [
      Event(id: "f2", loggedAt: at(2026, 7, 23, 9), kind: .custom),
      Event(id: "f1", loggedAt: at(2026, 7, 21, 9), kind: .custom),
      Event(id: "t1", loggedAt: at(2026, 7, 20, 9), kind: .feed),
      Event(id: "t2", loggedAt: at(2026, 7, 20, 8), kind: .nappy),
      Event(id: "y1", loggedAt: at(2026, 7, 19, 22), kind: .sleep),
    ]
    let sections = Timeline.sections(events, now: now, calendar: london)
    XCTAssertEqual(sections.map(\.label), ["Tomorrow", "23 Aug 2026", "Today", "Yesterday"])
    XCTAssertEqual(sections[2].items.map(\.id), ["t1", "t2"])
  }

  func testPatternWindowAndFilter() {
    let end = at(2026, 7, 20, 10)
    let window = Timeline.patternWindow(days: 7, rangeEndMs: end, calendar: london)
    XCTAssertEqual(window.startMs, at(2026, 7, 14))
    XCTAssertEqual(window.endMs, at(2026, 7, 21))
    let events = [
      Event(loggedAt: at(2026, 7, 13, 23), kind: .sleep),
      Event(loggedAt: at(2026, 7, 14, 1), kind: .sleep),
      Event(loggedAt: at(2026, 7, 15, 1), kind: .feed),
    ]
    XCTAssertEqual(Timeline.filter(events, kind: .sleep, window: window).count, 1)
    XCTAssertEqual(Timeline.filter(events, kind: nil, window: nil).count, 3)
  }

  func testPatternDays() {
    let end = at(2026, 7, 20, 10)
    let items = [PatternItem(startMs: at(2026, 7, 19, 20), endMs: at(2026, 7, 20, 6), durationMinutes: 600)]
    let days = Patterns.days(items, days: 7, rangeEndMs: end, calendar: london)
    XCTAssertEqual(days.count, 7)
    XCTAssertEqual(days.first?.label, "Fri 14")
    XCTAssertEqual(days.last?.label, "Thu 20")
    XCTAssertEqual(days[5].slices, [DaySlice(dayStartMs: at(2026, 7, 19), startMin: 1200, endMin: 1440)])
    XCTAssertEqual(days[6].slices, [DaySlice(dayStartMs: at(2026, 7, 20), startMin: 0, endMin: 360)])
    XCTAssertEqual(Patterns.sessionsPerDay(0), "—")
    XCTAssertEqual(Patterns.sessionsPerDay(1.25), "1.3")
    XCTAssertEqual(Patterns.minutesPerDay(130.4), "2h 10m")
    XCTAssertEqual(Patterns.minutesPerDay(0), "—")
  }
}
