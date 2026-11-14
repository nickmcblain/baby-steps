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

final class CaughtUpTests: XCTestCase {
  private let window = FeedWindow(intervalMs: 3 * hourMs, label: "about 3 hours", shouldWakeForFeeds: true, reason: "")
  private let now = at(2026, 10, 14, 14, 0)

  func testCaughtUpAfterARecentFeed() {
    let state = CaughtUp.state(lastFeedEndedAt: now - hourMs, window: window, napAt: nil, timerRunning: false, now: now)
    XCTAssertEqual(state?.nextFeedAt, now + 2 * hourMs)
    XCTAssertEqual(state?.detail(calendar: london), "Next feed around 4:00 pm. Rest if you can.")
  }

  func testNotCaughtUpWhenFeedIsNearlyDue() {
    XCTAssertNil(CaughtUp.state(lastFeedEndedAt: now - 2.6 * hourMs, window: window, napAt: nil, timerRunning: false, now: now))
    XCTAssertNil(CaughtUp.state(lastFeedEndedAt: now - 4 * hourMs, window: window, napAt: nil, timerRunning: false, now: now))
  }

  func testNotCaughtUpWithoutAFeedOrWindow() {
    XCTAssertNil(CaughtUp.state(lastFeedEndedAt: nil, window: window, napAt: nil, timerRunning: false, now: now))
    XCTAssertNil(CaughtUp.state(lastFeedEndedAt: now - hourMs, window: nil, napAt: nil, timerRunning: false, now: now))
  }

  func testNotCaughtUpWhenANapIsDueOrATimerRuns() {
    XCTAssertNil(CaughtUp.state(lastFeedEndedAt: now - hourMs, window: window, napAt: now + 10 * minuteMs, timerRunning: false, now: now))
    XCTAssertNil(CaughtUp.state(lastFeedEndedAt: now - hourMs, window: window, napAt: now - minuteMs, timerRunning: false, now: now))
    XCTAssertNil(CaughtUp.state(lastFeedEndedAt: now - hourMs, window: window, napAt: nil, timerRunning: true, now: now))
    XCTAssertNotNil(CaughtUp.state(lastFeedEndedAt: now - hourMs, window: window, napAt: now + hourMs, timerRunning: false, now: now))
  }

  func testFutureFeedDoesNotCount() {
    XCTAssertNil(CaughtUp.state(lastFeedEndedAt: now + hourMs, window: window, napAt: nil, timerRunning: false, now: now))
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
