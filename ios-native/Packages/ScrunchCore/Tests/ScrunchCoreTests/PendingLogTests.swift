import XCTest
@testable import ScrunchCore

final class PendingLogTests: XCTestCase {
  private func freshDefaults() -> UserDefaults {
    let name = "PendingLogTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
  }

  func testEveryLogMapsToItsConvexMutation() {
    let cases: [(LogEntry, String)] = [
      (.feed(.bottle, side: nil, minutes: nil, amountMl: 120, milk: .formula), "events:logFeed"),
      (.nappy(.wet), "events:logNappy"),
      (.potty(.dirty), "events:logPotty"),
      (.sleep(minutes: 45), "events:logSleep"),
      (.tummy(minutes: 5), "events:logTummy"),
      (.pump(.left, minutes: 15, amountMl: 80), "events:logPump"),
      (.weight(grams: 4200), "events:logWeight"),
      (.height(cm: 55.5), "events:logHeight"),
      (.medicine(title: "Calpol"), "events:logMedicine"),
      (.activity(title: "Bath", minutes: 10), "events:logActivity"),
      (.custom(title: "First smile"), "events:logCustom"),
    ]
    for (log, name) in cases {
      XCTAssertEqual(PendingLog(babyId: "b1", loggedAt: 1_000, log: log).call.name, name)
    }
  }

  func testBreastFeedDropsBottleFieldsAndBottleDropsSide() {
    let breast = PendingLog(babyId: "b1", loggedAt: 1_000, log: .feed(.breast, side: .left, minutes: 12, amountMl: 90, milk: .formula)).call
    XCTAssertEqual(breast.args["side"], .string("left"))
    XCTAssertEqual(breast.args["durationMinutes"], .number(12))
    XCTAssertNil(breast.args["amountMl"])
    XCTAssertNil(breast.args["milk"])

    let bottle = PendingLog(babyId: "b1", loggedAt: 1_000, log: .feed(.bottle, side: .right, minutes: nil, amountMl: 120, milk: .expressed)).call
    XCTAssertNil(bottle.args["side"])
    XCTAssertEqual(bottle.args["amountMl"], .number(120))
    XCTAssertEqual(bottle.args["milk"], .string("expressed"))
  }

  func testNappyArgs() {
    let call = PendingLog(babyId: "b1", loggedAt: 1_000, log: .nappy(.both), note: "Blowout").call
    XCTAssertEqual(call.args["babyId"], .string("b1"))
    XCTAssertEqual(call.args["loggedAt"], .number(1_000))
    XCTAssertEqual(call.args["nappy"], .string("both"))
    XCTAssertEqual(call.args["note"], .string("Blowout"))
    XCTAssertEqual(call.args["weeSize"], .string("medium"))
    XCTAssertEqual(call.args["pooSize"], .string("medium"))

    let wet = PendingLog(babyId: "b1", loggedAt: 1_000, log: .nappy(.wet)).call
    XCTAssertEqual(wet.args["weeSize"], .string("medium"))
    XCTAssertNil(wet.args["pooSize"])
  }

  func testSummariesUseUKCopy() {
    XCTAssertEqual(LogEntry.nappy(.wet).summary(format: gb), "Wet nappy")
    XCTAssertEqual(LogEntry.nappy(.dirty).summary(format: gb), "Dirty nappy")
    XCTAssertEqual(LogEntry.nappy(.both).summary(format: gb), "Wet and dirty nappy")
    XCTAssertEqual(LogEntry.potty(.both).summary(format: gb), "Potty · Wee + poo")
    XCTAssertEqual(LogEntry.feed(.bottle, side: nil, minutes: nil, amountMl: 120, milk: nil).summary(format: gb), "Bottle · 120 ml")
    XCTAssertEqual(LogEntry.feed(.breast, side: .right, minutes: 10, amountMl: nil, milk: nil).summary(format: gb), "Feed · Right · 10 min")
    XCTAssertEqual(LogEntry.weight(grams: 4250).summary(format: gb), "Weight · 4.25 kg")
    XCTAssertEqual(LogEntry.height(cm: 55).summary(format: gb), "Height · 55 cm")
  }

  func testQueueRoundTripsAndRemovesById() {
    let queue = PendingLogQueue(defaults: freshDefaults())
    XCTAssertTrue(queue.all.isEmpty)
    let first = PendingLog(id: "a", babyId: "b1", loggedAt: 1, log: .nappy(.wet))
    let second = PendingLog(id: "b", babyId: "b1", loggedAt: 2, log: .feed(.breast, side: .both, minutes: 20, amountMl: nil, milk: nil), note: "Left 10 min · Right 10 min")
    queue.enqueue(first)
    queue.enqueue(second)
    XCTAssertEqual(queue.all, [first, second])
    queue.remove(id: "a")
    XCTAssertEqual(queue.all, [second])
    queue.remove(id: "b")
    XCTAssertTrue(queue.all.isEmpty)
  }

  func testSharedBabiesFallsBackToFirstBaby() {
    let defaults = freshDefaults()
    XCTAssertNil(SharedBabies.load(from: defaults).active)
    let babies = SharedBabies(babies: [.init(id: "b1", name: "Nico"), .init(id: "b2", name: "Ada")], activeId: "b2")
    XCTAssertTrue(babies.save(to: defaults))
    XCTAssertFalse(babies.save(to: defaults))
    XCTAssertEqual(SharedBabies.load(from: defaults).active?.name, "Ada")
    XCTAssertEqual(SharedBabies(babies: babies.babies, activeId: "gone").active?.id, "b1")
  }

  func testFinishedSleepTimerBecomesASleepLog() {
    let start = at(2025, 0, 10, 13, 0)
    var session = TimerSession(kind: .sleep, babyId: "b1", babyName: "Nico", now: start)
    session.toggle(now: start)
    session.pause(now: start + 42 * 60_000)
    let log = session.finishedLog()
    XCTAssertEqual(log?.log, .sleep(minutes: 42))
    XCTAssertEqual(log?.loggedAt, start)
    XCTAssertEqual(log?.call.name, "events:logSleep")
  }

  func testFinishedFeedTimerKeepsBothSidesNote() {
    let start = at(2025, 0, 10, 9, 0)
    var session = TimerSession(kind: .feed, babyId: "b1", babyName: nil, now: start)
    session.tapSide(.left, now: start)
    session.tapSide(.right, now: start + 8 * 60_000)
    session.pause(now: start + 18 * 60_000)
    let log = session.finishedLog()
    XCTAssertEqual(log?.log, .feed(.breast, side: .both, minutes: 18, amountMl: nil, milk: nil))
    XCTAssertEqual(log?.note, "Left 8 min · Right 10 min")
  }

  func testVeryShortTimerSavesNothing() {
    var session = TimerSession(kind: .tummy, babyId: "b1", babyName: nil, now: 0)
    session.toggle(now: 0)
    session.pause(now: 3_000)
    XCTAssertNil(session.finishedLog())
  }

  func testSnapshotShowsAQueuedNappyAndFeed() {
    let now = at(2025, 0, 10, 21, 41)
    let nappy = GlanceSnapshot.placeholder.applying(PendingLog(babyId: "b1", loggedAt: now, log: .nappy(.dirty)), calendar: london)
    XCTAssertEqual(nappy.lastNappy, "Poo · \(Clock.time(now, calendar: london))")
    XCTAssertEqual(nappy.lastFeed, GlanceSnapshot.placeholder.lastFeed)

    let feed = GlanceSnapshot.placeholder.applying(PendingLog(babyId: "b1", loggedAt: now, log: .feed(.bottle, side: nil, minutes: nil, amountMl: 90, milk: nil)), calendar: london)
    XCTAssertEqual(feed.lastFeed, "Bottle · \(Clock.time(now, calendar: london))")
  }
}
