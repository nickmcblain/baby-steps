import XCTest
@testable import ScrunchCore

final class TimerSessionTests: XCTestCase {
  func testClockFormat() {
    XCTAssertEqual(TimerClock.format(0), "00:00")
    XCTAssertEqual(TimerClock.format(65_999), "01:05")
    XCTAssertEqual(TimerClock.format(3_725_000), "1:02:05")
    XCTAssertEqual(TimerClock.format(-5), "00:00")
  }

  func testMinutesRounding() {
    XCTAssertEqual(TimerSession.minutes(fromMs: 4_999), 0)
    XCTAssertEqual(TimerSession.minutes(fromMs: 5_000), 1)
    XCTAssertEqual(TimerSession.minutes(fromMs: 89_999), 1)
    XCTAssertEqual(TimerSession.minutes(fromMs: 90_000), 2)
  }

  func testSleepStartPauseResume() {
    var session = TimerSession(kind: .sleep, babyId: "b1", babyName: "Nico", now: 0)
    XCTAssertFalse(session.isRunning)
    session.toggle(now: 1_000)
    XCTAssertTrue(session.isAsleep(babyId: "b1"))
    XCTAssertFalse(session.isAsleep(babyId: "b2"))
    XCTAssertEqual(session.elapsed(now: 61_000), 60_000)
    session.toggle(now: 61_000)
    XCTAssertFalse(session.isRunning)
    XCTAssertEqual(session.elapsed(now: 999_999), 60_000)
    session.toggle(now: 100_000)
    XCTAssertEqual(session.elapsed(now: 130_000), 90_000)
    session.pause(now: 130_000)
    XCTAssertEqual(session.handoff()?.minutes, 2)
  }

  func testFeedSidesSwitchAndPause() {
    var session = TimerSession(kind: .feed, babyId: "b1", babyName: nil, now: 0)
    session.tapSide(.left, now: 0)
    XCTAssertEqual(session.activeSide, .left)
    session.tapSide(.right, now: 300_000) // left 5 min, switch to right
    XCTAssertEqual(session.activeSide, .right)
    XCTAssertEqual(session.sideElapsed(.left, now: 999_999), 300_000)
    session.tapSide(.right, now: 720_000) // pause right after 7 min
    XCTAssertNil(session.activeSide)
    XCTAssertEqual(session.sideElapsed(.right, now: 999_999), 420_000)
    let handoff = session.handoff()
    XCTAssertEqual(handoff?.minutes, 12)
    XCTAssertEqual(handoff?.side, .both)
    XCTAssertEqual(handoff?.bothSidesNote, "Left 5 min · Right 7 min")
  }

  func testSingleSideHandoff() {
    var session = TimerSession(kind: .pump, babyId: "b1", babyName: nil, now: 0)
    session.tapSide(.right, now: 0)
    session.pause(now: 600_000)
    XCTAssertEqual(session.handoff()?.side, .right)
    XCTAssertNil(session.handoff()?.bothSidesNote)
  }

  func testNothingToSaveUnderFiveSeconds() {
    var session = TimerSession(kind: .tummy, babyId: "b1", babyName: nil, now: 0)
    session.toggle(now: 0)
    XCTAssertFalse(session.canFinish(now: 4_000))
    session.pause(now: 4_000)
    XCTAssertNil(session.handoff())
  }

  func testPersistedJSONMatchesRNShape() throws {
    var session = TimerSession(kind: .sleep, babyId: "b1", babyName: "Nico", now: 1_000)
    session.toggle(now: 2_000)
    let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as! [String: Any]
    XCTAssertEqual(json["kind"] as? String, "sleep")
    XCTAssertEqual(json["sessionStartedAt"] as? Double, 1_000)
    XCTAssertEqual(json["sleepTickOrigin"] as? Double, 2_000)
    let decoded = try JSONDecoder().decode(TimerSession.self, from: JSONEncoder().encode(session))
    XCTAssertEqual(decoded, session)
  }

  func testLiveActivityContent() {
    var feed = TimerSession(kind: .feed, babyId: "b1", babyName: " Nico ", now: 0)
    feed.tapSide(.left, now: 0)
    let running = feed.liveActivityContent(now: 60_000)
    XCTAssertEqual(running.title, "Feed · Left")
    XCTAssertEqual(running.subtitle, "Nico")
    XCTAssertEqual(running.style, .feed)
    XCTAssertTrue(running.running)
    XCTAssertEqual(running.startEpochMs, 0)
    XCTAssertEqual(running.endEpochMs, DAY)

    var pump = TimerSession(kind: .pump, babyId: "b1", babyName: nil, now: 0)
    pump.tapSide(.right, now: 0)
    pump.pause(now: 125_000)
    let paused = pump.liveActivityContent(now: 200_000)
    XCTAssertEqual(paused.title, "Pump · Right")
    XCTAssertEqual(paused.style, .feed)
    XCTAssertFalse(paused.running)
    XCTAssertEqual(paused.pausedLabel, "02:05")

    let tummy = TimerSession(kind: .tummy, babyId: "b1", babyName: nil, now: 0).liveActivityContent(now: 0)
    XCTAssertEqual(tummy.title, "Tummy time")
    XCTAssertEqual(tummy.style, .tummy)
  }

  func testDeepLink() {
    XCTAssertEqual(TimerSession(kind: .tummy, babyId: "abc", babyName: nil, now: 0).deepLink, "babysteps://baby/abc/tummy/timer")
  }
}

final class ReminderPlanTests: XCTestCase {
  let newborn = Baby(id: "b1", name: "Nico", dateOfBirth: 0, weightGrams: 4000)
  let older = Baby(id: "b2", name: "Ada", dateOfBirth: 0, weightGrams: 7000)

  func testFeedSchedulesFromLastFeed() {
    let now = 10 * DAY
    guard case .schedule(let plan) = ReminderPlans.feed(baby: newborn, lastFeedAt: now - hourMs, sleepTimerRunning: false, now: now) else {
      return XCTFail("expected schedule")
    }
    XCTAssertEqual(plan.identifier, "feed-reminder:b1")
    XCTAssertEqual(plan.title, "Nico · feed check")
    XCTAssertEqual(plan.body, "Around about 2.5 hours since the last feed — time for a gentle check.")
    XCTAssertEqual(plan.fireAt, now - hourMs + 2.5 * hourMs)
  }

  func testOverdueFeedFiresInAMinute() {
    let now = 10 * DAY
    guard case .schedule(let plan) = ReminderPlans.feed(baby: newborn, lastFeedAt: now - 5 * hourMs, sleepTimerRunning: false, now: now) else {
      return XCTFail("expected schedule")
    }
    XCTAssertEqual(plan.fireAt, now + 60_000)
  }

  func testSleepTimerSuppressesOnlyWhenGuidanceAllows() {
    let now = 200 * DAY
    XCTAssertEqual(
      ReminderPlans.feed(baby: older, lastFeedAt: now, sleepTimerRunning: true, now: now),
      .suppressedForSleep(dueAt: now + 4 * hourMs)
    )
    guard case .schedule(let plan) = ReminderPlans.feed(baby: older, lastFeedAt: now, sleepTimerRunning: false, now: now) else {
      return XCTFail("expected schedule")
    }
    XCTAssertEqual(plan.body, "Around about 4 hours since the last feed — offer if they're stirring.")
    // Newborns keep reminders even while asleep.
    if case .suppressedForSleep = ReminderPlans.feed(baby: newborn, lastFeedAt: 10 * DAY, sleepTimerRunning: true, now: 10 * DAY) {
      XCTFail("newborn should not be suppressed")
    }
    XCTAssertEqual(ReminderPlans.feed(baby: older, lastFeedAt: nil, sleepTimerRunning: false, now: now), .cancel)
  }

  func testNap() {
    let now = at(2026, 7, 20, 10)
    let napAt = at(2026, 7, 20, 12, 40)
    let plan = ReminderPlans.nap(babyId: "b1", babyName: "Nico", napAt: napAt, asleep: false, now: now, calendar: london)
    XCTAssertEqual(plan?.identifier, "nap-reminder:b1")
    XCTAssertEqual(plan?.title, "Nico · nap window soon")
    XCTAssertEqual(plan?.body, "Often ready around 12:40 pm. Watch for cues.")
    XCTAssertEqual(plan?.fireAt, napAt - 10 * 60_000)
    XCTAssertNil(ReminderPlans.nap(babyId: "b1", babyName: "Nico", napAt: napAt, asleep: true, now: now, calendar: london))
    XCTAssertNil(ReminderPlans.nap(babyId: "b1", babyName: "Nico", napAt: now + 5 * 60_000, asleep: false, now: now, calendar: london))
    XCTAssertNil(ReminderPlans.nap(babyId: "b1", babyName: "Nico", napAt: nil, asleep: false, now: now, calendar: london))
  }

  func testMedicine() {
    let plan = ReminderPlans.medicine(babyId: "b1", babyName: "Nico", name: " Calpol  Infant ", dose: "2.5 ml", hours: 4, now: 0)
    XCTAssertEqual(plan?.identifier, "medicine-reminder:b1:calpol-infant")
    XCTAssertEqual(plan?.title, "Nico ·  Calpol  Infant ")
    XCTAssertEqual(plan?.body, "Next dose due · 2.5 ml.")
    XCTAssertEqual(plan?.fireAt, 4 * hourMs)
    XCTAssertEqual(ReminderPlans.medicine(babyId: "b1", babyName: "Nico", name: "Calpol", dose: nil, hours: 6, now: 0)?.body, "Next dose due.")
    XCTAssertNil(ReminderPlans.medicine(babyId: "b1", babyName: "Nico", name: "Calpol", dose: nil, hours: nil, now: 0))
  }

  func testDigestCopy() {
    XCTAssertEqual(ReminderPlans.digestIdentifier("b1"), "digest:b1")
    XCTAssertEqual(ReminderPlans.digestTitle("Nico"), "Your week with Nico is ready")
  }
}
