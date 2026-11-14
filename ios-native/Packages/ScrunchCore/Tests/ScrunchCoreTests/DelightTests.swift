import XCTest
@testable import ScrunchCore

final class SaveCopyTests: XCTestCase {
  func testNamesTheBaby() {
    XCTAssertEqual(SaveCopy.logged(.feed, babyName: "Eliza"), "Logged Eliza's feed")
    XCTAssertEqual(SaveCopy.logged(.nappy, babyName: "Eliza"), "Logged Eliza's nappy")
    XCTAssertEqual(SaveCopy.logged(.tummy, babyName: "Eliza"), "Logged Eliza's tummy time")
    XCTAssertEqual(SaveCopy.logged(.potty, babyName: "Eliza"), "Logged Eliza's potty trip")
    XCTAssertEqual(SaveCopy.logged(.weight, babyName: "Eliza"), "Saved Eliza's weight")
    XCTAssertEqual(SaveCopy.logged(.custom, babyName: "Eliza"), "Saved Eliza's event")
  }

  func testUsesFirstNameAndUKPossessive() {
    XCTAssertEqual(SaveCopy.logged(.sleep, babyName: "  Eliza Rose "), "Logged Eliza's sleep")
    XCTAssertEqual(SaveCopy.logged(.feed, babyName: "James"), "Logged James's feed")
  }

  func testFallsBackWithoutAName() {
    XCTAssertEqual(SaveCopy.logged(.feed, babyName: nil), "Feed logged")
    XCTAssertEqual(SaveCopy.logged(.tummy, babyName: "  "), "Tummy time logged")
    XCTAssertEqual(SaveCopy.logged(.height, babyName: nil), "Height saved")
  }

  func testPumpIsTheParents() {
    XCTAssertEqual(SaveCopy.logged(.pump, babyName: "Eliza"), "Pump logged")
  }

  func testEveryKindHasCopy() {
    for kind in EventKind.allCases {
      XCTAssertFalse(SaveCopy.logged(kind, babyName: "Eliza").isEmpty)
    }
  }
}

final class AllCaughtUpTests: XCTestCase {
  let now = at(2026, 10, 14, 14, 0)

  // 20 days old, breastfed: typical gap about 2.5 hours; awake range 35–60 min.
  let baby = Baby(id: "b1", name: "Ada", dateOfBirth: at(2026, 10, 14, 14, 0) - 20 * DAY, weightGrams: 4200, feedingMode: .breast)

  func feed(_ hour: Int, _ minute: Int = 0) -> Event {
    Event(loggedAt: at(2026, 10, 14, hour, minute), kind: .feed, feedKind: .breast, side: .left)
  }

  func caughtUp(_ feeds: [Event], sleepEnd: EpochMs? = nil, asleep: Bool = false) -> Bool {
    Insights.allCaughtUp(InsightInput(baby: baby, now: now, recentFeeds: feeds, lastNappy: nil, lastSleepEndMs: sleepEnd, asleep: asleep))
  }

  func testCaughtUpAfterARecentFeed() {
    // Fed at 1pm, next likely 3:30 pm.
    XCTAssertTrue(caughtUp([feed(13)]))
  }

  func testAgreesWithTheNextFeedInsight() {
    let input = InsightInput(baby: baby, now: now, recentFeeds: [feed(13)], lastNappy: nil, lastSleepEndMs: nil, asleep: false)
    XCTAssertEqual(Insights.nextFeed(input, calendar: london)?.headline, "Next feed likely around 3:30 pm")
  }

  func testNotCaughtUpWhenAFeedIsNearOrDue() {
    // Fed 11:45, next likely 2:15 pm: inside the 30 minute margin.
    XCTAssertFalse(caughtUp([feed(11, 45)]))
    XCTAssertFalse(caughtUp([feed(10)]))
  }

  func testNotCaughtUpWithoutARecentFeed() {
    XCTAssertFalse(caughtUp([]))
    XCTAssertFalse(caughtUp([Event(loggedAt: now - 9 * hourMs, kind: .feed, feedKind: .breast)]))
    XCTAssertFalse(caughtUp([Event(loggedAt: now + hourMs, kind: .feed, feedKind: .breast)]))
  }

  func testNotCaughtUpWhenAwakeLongerThanUsual() {
    XCTAssertFalse(caughtUp([feed(13)], sleepEnd: now - 90 * minuteMs))
    XCTAssertTrue(caughtUp([feed(13)], sleepEnd: now - 30 * minuteMs))
    XCTAssertTrue(caughtUp([feed(13)], sleepEnd: now - 90 * minuteMs, asleep: true))
  }
}

final class MilestoneTests: XCTestCase {
  func testTitlesAreSentenceCase() {
    for milestone in Milestone.allCases {
      let title = milestone.title
      XCTAssertEqual(title.first?.isUppercase, true)
      XCTAssertEqual(title.dropFirst(), title.dropFirst().lowercased()[...], title)
    }
  }

  func testSavedCopy() {
    XCTAssertEqual(MilestoneCopy.saved(.firstSmile, babyName: "Eliza"), "Saved Eliza's first smile")
    XCTAssertEqual(MilestoneCopy.saved(.rolledOver, babyName: nil), "Rolled over saved")
  }

  func testRowsKeepCatalogueOrderAndSkipUnknownKeys() throws {
    let json = Data("""
    [{"key":"rolledOver","reachedAt":200},{"key":"wavedHello","reachedAt":300},{"key":"rolledOver","reachedAt":100}]
    """.utf8)
    let marks = try JSONDecoder().decode([MilestoneMark].self, from: json)
    let rows = MilestoneCopy.rows(marks)
    XCTAssertEqual(rows.map(\.milestone), Milestone.allCases)
    XCTAssertEqual(rows.first { $0.milestone == .rolledOver }?.reachedAt, 100)
    XCTAssertEqual(rows.compactMap(\.reachedAt).count, 1)
  }

  func testMilestoneArgsEncodeAsKeys() {
    let call = API.babies.setMilestone(babyId: "b1", milestone: .firstSmile, reachedAt: 5)
    XCTAssertEqual(call.args["key"], .string("firstSmile"))
    XCTAssertEqual(call.args["reachedAt"], .number(5))
  }
}
