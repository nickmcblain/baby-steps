import XCTest
@testable import ScrunchCore

final class CareExportTests: XCTestCase {
  private let tz = TimeZone(identifier: "Europe/London")!
  private let now = at(2026, 10, 14, 12)

  private func log(_ events: [Event]) -> CareLog {
    CareLog(baby: Baby(id: "b1", name: "Ada Lovelace", dateOfBirth: at(2026, 8, 1), weightGrams: 3400), events: events)
  }

  func testRowsUseUKDatesAndLocalTimeAcrossBST() {
    let rows = CareExport.rows(log([
      Event(loggedAt: at(2026, 9, 25, 23, 30), kind: .sleep, durationMinutes: 90),
      Event(loggedAt: at(2026, 7, 20, 9, 5), kind: .feed, feedKind: .bottle, amountMl: 120, milk: .formula),
    ]), timeZone: tz, now: now)

    XCTAssertEqual(rows.map(\.date), ["20/08/2026", "25/10/2026"])
    XCTAssertEqual(rows.map(\.time), ["09:05", "23:30"])
    XCTAssertEqual(rows[0].type, "Feed")
    XCTAssertEqual(rows[0].details, "120 ml Formula")
    XCTAssertEqual(rows[0].amountMl, "120")
    XCTAssertEqual(rows[1].durationMinutes, "90")
    XCTAssertEqual(rows[1].details, "1h 30m")
  }

  func testGrowthColumns() {
    let rows = CareExport.rows(log([
      Event(loggedAt: at(2026, 9, 1), kind: .weight, weightGrams: 4255),
      Event(loggedAt: at(2026, 9, 2), kind: .height, heightCm: 54.5),
    ]), timeZone: tz, now: now)
    XCTAssertEqual(rows[0].weightKg, "4.26")
    XCTAssertEqual(rows[1].lengthCm, "54.5")
  }

  func testCSVHeaderEscapingAndFormulaGuard() {
    let csv = CareExport.csv(log([
      Event(loggedAt: at(2026, 9, 1, 8), kind: .medicine, title: "=HYPERLINK(\"x\")", note: "Gave it, \"as told\"\nby GP"),
      Event(loggedAt: at(2026, 9, 1, 9), kind: .custom, title: "-1 day", note: "-3"),
    ]), timeZone: tz, now: now)
    let lines = csv.components(separatedBy: "\r\n")
    XCTAssertEqual(lines[0], "Date,Time,Type,Details,Duration (min),Amount (ml),Weight (kg),Length (cm),Note")
    XCTAssertTrue(lines[1].hasPrefix("01/10/2026,08:00,Medicine,\"'=HYPERLINK(\"\"x\"\")\""))
    XCTAssertTrue(lines[1].hasSuffix(",\"Gave it, \"\"as told\"\"\nby GP\""))
    XCTAssertTrue(csv.contains(",'-1 day,"))
    XCTAssertTrue(csv.hasSuffix(",-3\r\n"), "plain negative numbers stay numbers")
  }

  func testCSVWithNoEventsIsJustTheHeader() {
    XCTAssertEqual(CareExport.csv(log([]), timeZone: tz, now: now).components(separatedBy: "\r\n").filter { !$0.isEmpty }.count, 1)
  }

  func testDaysGroupNewestFirst() {
    let days = CareExport.days(log([
      Event(loggedAt: at(2026, 9, 1, 8), kind: .nappy, nappy: .wee, weeSize: .small),
      Event(loggedAt: at(2026, 9, 2, 7), kind: .sleep, durationMinutes: 30),
      Event(loggedAt: at(2026, 9, 1, 20), kind: .tummy, durationMinutes: 5),
    ]), timeZone: tz, now: now)
    XCTAssertEqual(days.map(\.heading), ["Friday 2 October 2026", "Thursday 1 October 2026"])
    XCTAssertEqual(days[1].rows.map(\.time), ["08:00", "20:00"])
  }

  func testFileNameAndSubtitle() {
    XCTAssertEqual(
      CareExport.fileName(babyName: "Ada Lovelace", now: now, timeZone: tz, ext: "csv"),
      "Scrunch-Ada-Lovelace-care-log-2026-11-14.csv"
    )
    XCTAssertEqual(CareExport.fileName(babyName: "  ", now: now, timeZone: tz, ext: "pdf"), "Scrunch-baby-care-log-2026-11-14.pdf")
    XCTAssertEqual(
      CareExport.subtitle(log([Event(loggedAt: now, kind: .feed)]), timeZone: tz, now: now),
      "Born 1 September 2026 · 1 entry · Exported 14 November 2026"
    )
  }

  func testCareLogDecodesConvexPayload() throws {
    let json = """
    {"baby":{"_id":"b1","_creationTime":1,"name":"Ada","dateOfBirth":0,"weightGrams":3400,"inviteCode":"ABC234","createdBy":"u1"},
     "events":[{"_id":"e1","_creationTime":2,"babyId":"b1","createdBy":"u1","loggedAt":5,"kind":"sleep","durationMinutes":30}],
     "truncated":false}
    """
    let decoded = try JSONDecoder().decode(CareLog.self, from: Data(json.utf8))
    XCTAssertEqual(decoded.events.first?.kind, .sleep)
    XCTAssertEqual(API.careExport.babyCareLog("b1").name, "careExport:babyCareLog")
    XCTAssertEqual(API.account.deleteAccount().name, "account:deleteAccount")
  }
}

final class AIDisclosureTests: XCTestCase {
  func testConsentOnlyCountsForTheCurrentVersion() {
    XCTAssertFalse(AIDisclosure.hasConsented(nil))
    XCTAssertFalse(AIDisclosure.hasConsented("ai-v0"))
    XCTAssertTrue(AIDisclosure.hasConsented(AIDisclosure.consentVersion))
  }

  func testDisclosureNamesTheProvidersAndWhatIsSent() {
    XCTAssertTrue(AIDisclosure.provider.contains("OpenRouter"))
    XCTAssertTrue(AIDisclosure.provider.contains("Gemini"))
    XCTAssertTrue(AIDisclosure.sent.contains { $0.contains("name") })
  }
}
