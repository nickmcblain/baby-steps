import XCTest
@testable import ScrunchCore

final class QuickLogTests: XCTestCase {
  private func breast(_ side: Side?, at loggedAt: EpochMs = 0) -> Event {
    Event(loggedAt: loggedAt, kind: .feed, feedKind: .breast, side: side)
  }

  func testSuggestedSideAlternates() {
    XCTAssertEqual(QuickLog.suggestedSide(lastFeed: breast(.left)), .right)
    XCTAssertEqual(QuickLog.suggestedSide(lastFeed: breast(.right)), .left)
    XCTAssertEqual(QuickLog.suggestedSide(lastFeed: breast(.both)), .left)
    XCTAssertEqual(QuickLog.suggestedSide(lastFeed: nil), .left)
    XCTAssertEqual(QuickLog.suggestedSide(lastFeed: Event(loggedAt: 0, kind: .feed, feedKind: .bottle, amountMl: 90)), .left)
  }

  func testLastSideLine() {
    let now = 2 * 3_600_000.0 + 5 * 60_000
    XCTAssertEqual(QuickLog.lastSideLine(lastFeed: breast(.left), now: now), "Last side: Left, 2h 5m ago")
    XCTAssertEqual(QuickLog.lastSideLine(lastFeed: breast(.both), now: 30_000), "Last side: Both, just now")
    XCTAssertNil(QuickLog.lastSideLine(lastFeed: breast(nil), now: now))
    XCTAssertNil(QuickLog.lastSideLine(lastFeed: nil, now: now))
    XCTAssertNil(QuickLog.lastSideLine(lastFeed: Event(loggedAt: 0, kind: .feed, feedKind: .bottle), now: now))
  }

  func testNappyDefaultsMatchTheForm() {
    XCTAssertEqual(QuickLog.Nappy.wet.kind, .wee)
    XCTAssertEqual(QuickLog.Nappy.wet.weeSize, .medium)
    XCTAssertNil(QuickLog.Nappy.wet.pooSize)
    XCTAssertEqual(QuickLog.Nappy.dirty.kind, .poo)
    XCTAssertNil(QuickLog.Nappy.dirty.weeSize)
    XCTAssertEqual(QuickLog.Nappy.dirty.pooSize, .medium)
    XCTAssertEqual(QuickLog.Nappy.both.kind, .both)
    XCTAssertEqual(QuickLog.Nappy.both.weeSize, .medium)
    XCTAssertEqual(QuickLog.Nappy.both.pooSize, .medium)
    XCTAssertEqual(QuickLog.Nappy.both.loggedCopy, "Wet and dirty nappy logged")
  }

  func testSavedAndStartedCopy() {
    let t = at(2026, 6, 1, 14, 32)
    XCTAssertEqual(QuickLog.savedCopy("Wet nappy logged", loggedAt: t, calendar: london), "Wet nappy logged · 14:32")
    let session = TimerSession(kind: .sleep, babyId: "b1", babyName: nil, now: t)
    XCTAssertEqual(QuickLog.startedCopy(session, calendar: london), "Started 14:32")
    XCTAssertEqual(QuickLog.startedCopy(session, calendar: calendar("en_US", timeZone: "Europe/London")), "Started 2:32\u{202F}PM")
  }

  func testShiftedSavedLogSnapsToMinute() {
    let t = at(2026, 6, 1, 14, 32) + 20_000
    XCTAssertEqual(QuickLog.shifted(t, minutes: 5), at(2026, 6, 1, 14, 27))
  }

  func testStartedSessionsRunImmediately() {
    let feed = TimerSession.started(kind: .feed, side: .right, babyId: "b1", babyName: "Nico", now: 1_000)
    XCTAssertTrue(feed.isRunning)
    XCTAssertEqual(feed.activeSide, .right)
    XCTAssertEqual(QuickLog.runningTitle(feed), "Feeding · Right")
    XCTAssertEqual(QuickLog.startedToast(feed), "Feed started · Right")

    let sleep = TimerSession.started(kind: .sleep, babyId: "b1", babyName: nil, now: 1_000)
    XCTAssertTrue(sleep.isAsleep(babyId: "b1"))
    XCTAssertEqual(QuickLog.runningTitle(sleep), "Asleep")
  }

  func testShiftStartOnSleepAddsTimeAndMovesStart() {
    var session = TimerSession.started(kind: .sleep, babyId: "b1", babyName: nil, now: 600_000)
    session.shiftStart(byMinutes: 5)
    XCTAssertEqual(session.sessionStartedAt, 300_000)
    XCTAssertEqual(session.elapsed(now: 660_000), 360_000)
    session.pause(now: 660_000)
    XCTAssertEqual(session.handoff()?.minutes, 6)
    XCTAssertEqual(session.handoff()?.startedAt, 300_000)
  }

  func testShiftStartOnFeedCreditsTheRunningSide() {
    var session = TimerSession.started(kind: .feed, side: .left, babyId: "b1", babyName: nil, now: 0)
    session.tapSide(.right, now: 60_000)
    session.shiftStart(byMinutes: 5)
    XCTAssertEqual(session.sideElapsed(.left, now: 120_000), 60_000)
    XCTAssertEqual(session.sideElapsed(.right, now: 120_000), 360_000)
  }

  func testShiftStartOnPausedFeedCreditsTheBusierSide() {
    var session = TimerSession.started(kind: .feed, side: .right, babyId: "b1", babyName: nil, now: 0)
    session.pause(now: 120_000)
    session.shiftStart(byMinutes: 15)
    XCTAssertEqual(session.rightBaseMs, 120_000 + 900_000)
    XCTAssertEqual(session.leftBaseMs, 0)
  }

  func testShiftStartIgnoresNonPositive() {
    var session = TimerSession.started(kind: .tummy, babyId: "b1", babyName: nil, now: 0)
    let before = session
    session.shiftStart(byMinutes: 0)
    session.shiftStart(byMinutes: -5)
    XCTAssertEqual(session, before)
  }
}
