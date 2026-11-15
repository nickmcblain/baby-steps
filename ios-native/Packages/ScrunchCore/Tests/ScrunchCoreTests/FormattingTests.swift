import XCTest
@testable import ScrunchCore

// Expected strings come from running lib/format.ts, lib/eventCopy.ts etc. in Node.

final class FormatTests: XCTestCase {
  func testAge() {
    let ages = [0, 1, 13, 14, 20, 90, 91, 400, 730, 800].map { Format.age(dateOfBirth: 0, now: Double($0) * DAY) }
    XCTAssertEqual(ages, [
      "0 days", "1 day", "13 days", "2 weeks", "2 weeks", "12 weeks", "2 months", "13 months", "23 months", "2y 2mo",
    ])
  }

  func testWeight() {
    XCTAssertEqual(gb.weight(3400), "3.4 kg")
    XCTAssertEqual(gb.weight(3400, unit: .lb), "7 lb 8 oz")
    XCTAssertEqual(gb.weight(3450), "3.5 kg")
    XCTAssertEqual(gb.weight(3450, unit: .lb), "7 lb 10 oz")
    XCTAssertEqual(gb.weight(7250), "7.3 kg")
    XCTAssertEqual(gb.weight(7250, unit: .lb), "16 lb 0 oz")
    XCTAssertEqual(gb.weight(2000), "2 kg")
    XCTAssertEqual(gb.weight(2000, unit: .lb), "4 lb 7 oz")
  }

  func testWeightRoundTrips() {
    XCTAssertEqual(Format.kgPartsToGrams(kg: 3, tenths: 4), 3400)
    XCTAssertEqual(Format.lbOzToGrams(lb: 7, oz: 8), 3402)
    let parts = Format.gramsToLbOz(Format.lbOzToGrams(lb: 9, oz: 15))
    XCTAssertEqual(parts.lb, 9)
    XCTAssertEqual(parts.oz, 15)
  }

  func testHeight() {
    XCTAssertEqual(gb.length(50), "50 cm")
    XCTAssertEqual(gb.length(50, unit: .inches), "1′ 8″")
    XCTAssertEqual(gb.length(50.55), "50.6 cm")
    XCTAssertEqual(gb.length(76.2), "76.2 cm")
    XCTAssertEqual(gb.length(76.2, unit: .inches), "2′ 6″")
    XCTAssertEqual(Format.ftInToCm(ft: 2, inch: 6), 76.2)
    XCTAssertEqual(Format.cmPartsToCm(whole: 50, tenths: 5), 50.5)
  }

  func testDobIsUTC() {
    XCTAssertEqual(Format.dob(Format.dobMs(year: 2026, month: 1, day: 3), calendar: london), "3 Jan 2026")
  }

  func testRelative() {
    let values = [0, 59_000, 60_000, 3_599_000, 3_600_000, 90_060_000, 3 * DAY].map { Format.relative(0, now: $0) }
    XCTAssertEqual(values, ["just now", "just now", "1m ago", "59m ago", "1h 0m ago", "1d ago", "3d ago"])
  }
}

final class EventCopyTests: XCTestCase {
  func testDuration() {
    XCTAssertEqual(EventCopy.durationMinutes(0), "")
    XCTAssertEqual(EventCopy.durationMinutes(45), "45 min")
    XCTAssertEqual(EventCopy.durationMinutes(60), "1h")
    XCTAssertEqual(EventCopy.durationMinutes(95), "1h 35m")
  }

  func testFeed() {
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .feed, feedKind: .bottle, amountMl: 120, milk: .formula), format: gb), "120 ml Formula")
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .feed, feedKind: .bottle, milk: .expressed), format: gb), "? ml Expressed")
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .feed, feedKind: .breast, side: .left, durationMinutes: 12)), "Breast left · 12 min")
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .feed, feedKind: .breast, side: .both)), "Breast both sides")
  }

  func testNappy() {
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .nappy, nappy: .both, weeSize: .medium, pooSize: .small)), "Wee Medium · Poo Small")
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .nappy, nappy: .wee)), "Wee")
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .nappy)), "Nappy")
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .potty, nappy: .poo, pooSize: .large)), "Poo Large")
  }

  func testOtherKinds() {
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .weight, weightGrams: 3400), format: gb), "3.4 kg")
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .height, heightCm: 50.5), format: gb), "50.5 cm")
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .sleep, durationMinutes: 90)), "1h 30m")
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .sleep)), "Sleep")
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .tummy, durationMinutes: 5)), "5 min")
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .custom, title: "  GP visit ")), "GP visit")
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .custom, title: "  ")), "Event")
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .pump, side: .right, durationMinutes: 15, amountMl: 80), format: gb), "Right · 15 min · 80 ml")
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .pump)), "Both sides")
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .medicine, title: "Calpol")), "Calpol")
    XCTAssertEqual(EventCopy.title(Event(loggedAt: 0, kind: .activity, durationMinutes: 75, title: "Bath")), "Bath · 1h 15m")
  }

  func testKindLabels() {
    XCTAssertEqual(EventCopy.kindLabel(Event(loggedAt: 100, kind: .custom), now: 50), "Upcoming")
    XCTAssertEqual(EventCopy.kindLabel(Event(loggedAt: 100, kind: .custom), now: 150), "Event")
    XCTAssertEqual(EventCopy.kindLabel(Event(loggedAt: 0, kind: .tummy), now: 0), "Tummy time")
  }
}

final class WeekGridTests: XCTestCase {
  func testStartOfWeekMonday() {
    // Sun 9 Aug 2026 → Mon 3 Aug
    XCTAssertEqual(WeekGrid.startOfWeekMonday(at(2026, 7, 9, 15), calendar: london), at(2026, 7, 3))
    XCTAssertEqual(WeekGrid.startOfWeekMonday(at(2026, 7, 3, 0, 1), calendar: london), at(2026, 7, 3))
  }

  func testLabelsAndRange() {
    let labels = WeekGrid.weekDayLabels(at(2026, 7, 3), calendar: london)
    XCTAssertEqual(labels.map(\.label), ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
    XCTAssertEqual(labels.map(\.dateNum), [3, 4, 5, 6, 7, 8, 9])
    XCTAssertEqual(WeekGrid.formatWeekRange(at(2026, 7, 3), calendar: london), "3\u{2009}–\u{2009}9 Aug")
    XCTAssertEqual(WeekGrid.formatWeekRange(at(2026, 6, 27), calendar: london), "27 Jul\u{2009}–\u{2009}2 Aug")
  }

  func testDSTWeekHasSevenDistinctMidnights() {
    // Week containing the 25 Oct 2026 clock change.
    let labels = WeekGrid.weekDayLabels(at(2026, 9, 19), calendar: london)
    XCTAssertEqual(labels.map(\.dateNum), [19, 20, 21, 22, 23, 24, 25])
    XCTAssertEqual(labels.last?.dayStartMs, at(2026, 9, 25))
  }

  func testSplitAcrossLocalDays() {
    let slices = WeekGrid.splitAcrossLocalDays(at(2026, 7, 3, 22), at(2026, 7, 4, 6), calendar: london)
    XCTAssertEqual(slices, [
      DaySlice(dayStartMs: at(2026, 7, 3), startMin: 22 * 60, endMin: 1440),
      DaySlice(dayStartMs: at(2026, 7, 4), startMin: 0, endMin: 6 * 60),
    ])
    XCTAssertEqual(WeekGrid.splitAcrossLocalDays(10, 10, calendar: london), [])
  }

  func testHourLabels() {
    XCTAssertEqual([0, 3, 12, 15, 24, -3].map { WeekGrid.formatHourLabel($0, calendar: london) }, ["00", "03", "12", "15", "00", "21"])
  }
}

final class LoggedAtTests: XCTestCase {
  func testSnapAndClamp() {
    XCTAssertEqual(LoggedAt.snapToMinute(89_999), 60_000)
    XCTAssertEqual(LoggedAt.snapToMinute(90_000), 120_000)
    let now = at(2026, 7, 20, 14, 30)
    XCTAssertEqual(LoggedAt.resolve(now + 3_600_000, allowFuture: false, now: now), now)
    XCTAssertEqual(LoggedAt.resolve(now + 3_600_000, allowFuture: true, now: now), now + 3_600_000)
  }

  func testFormat() {
    XCTAssertEqual(LoggedAt.format(at(2026, 7, 20, 14, 30), calendar: london), "20 Aug · 14:30")
    XCTAssertEqual(LoggedAt.format(at(2026, 0, 5, 9, 5), calendar: london), "5 Jan · 09:05")
  }

  func testTimelineDay() {
    let now = at(2026, 7, 20, 10)
    XCTAssertEqual(LoggedAt.timelineDay(at(2026, 7, 20, 23), now: now, calendar: london), "Today")
    XCTAssertEqual(LoggedAt.timelineDay(at(2026, 7, 19, 1), now: now, calendar: london), "Yesterday")
    XCTAssertEqual(LoggedAt.timelineDay(at(2026, 7, 21, 9), now: now, calendar: london), "Tomorrow")
    XCTAssertEqual(LoggedAt.timelineDay(at(2026, 7, 18, 9), now: now, calendar: london), "Tue 18 Aug")
    XCTAssertEqual(LoggedAt.timelineDay(at(2025, 10, 7, 9), now: now, calendar: london), "Fri 7 Nov 2025")
  }
}

final class HomeCopyTests: XCTestCase {
  func testCountdown() {
    XCTAssertEqual(HomeCopy.countdown(0), "Now")
    XCTAssertEqual(HomeCopy.countdown(60_000 * 24.5), "25m")
    XCTAssertEqual(HomeCopy.countdown(120 * 60_000), "2h")
    XCTAssertEqual(HomeCopy.countdown(65 * 60_000), "1h 5m")
  }

  func testHours() {
    XCTAssertEqual(HomeCopy.hours(13.44), "13.4h")
    XCTAssertEqual(HomeCopy.hours(12), "12h")
    XCTAssertEqual(HomeCopy.hours(0), "0h")
  }

  func testStrips() {
    let now = 3 * 60 * 60_000.0
    XCTAssertEqual(HomeCopy.lastFeedStrip(nil, now: now), "No feeds yet")
    XCTAssertEqual(HomeCopy.lastFeedStrip(Event(loggedAt: 0, kind: .feed, feedKind: .bottle), now: now), "Bottle · 3h 0m ago")
    XCTAssertEqual(HomeCopy.lastFeedStrip(Event(loggedAt: 0, kind: .feed, feedKind: .breast, side: .both), now: now), "Both · 3h 0m ago")
    XCTAssertEqual(HomeCopy.lastNappyStrip(Event(loggedAt: 0, kind: .nappy, nappy: .both), now: now), "Wee + poo · 3h 0m ago")
    XCTAssertEqual(HomeCopy.lastSleepStrip(Event(loggedAt: 0, kind: .sleep, durationMinutes: 45), now: now), "45 min · 3h 0m ago")
    XCTAssertEqual(HomeCopy.lastSleepStrip(nil, now: now), "No sleep yet")
    XCTAssertEqual(HomeCopy.lastTummyStrip(Event(loggedAt: 0, kind: .tummy), now: now), "3h 0m ago")
  }

  func testGlanceSnapshot() {
    let now = at(2026, 7, 20, 10)
    let feed = Event(loggedAt: at(2026, 7, 20, 8, 5), kind: .feed, feedKind: .breast, side: .left)
    let nappy = Event(loggedAt: at(2026, 7, 20, 13, 40), kind: .nappy, nappy: .wee)
    let snapshot = GlanceSnapshot.make(
      babyName: "Nico", asleep: false, napAt: at(2026, 7, 20, 12, 40),
      lastFeed: feed, lastNappy: nappy, sleepMinutesToday: 804, now: now, calendar: london
    )
    XCTAssertEqual(snapshot, GlanceSnapshot(
      babyName: "Nico", nextNap: "Often ready ~12:40", lastFeed: "Left · 08:05",
      lastNappy: "Wee · 13:40", sleepToday: "13.4h today"
    ))
    XCTAssertEqual(GlanceSnapshot.make(babyName: "Nico", asleep: true, napAt: nil, lastFeed: nil, lastNappy: nil, sleepMinutesToday: 0, now: now, calendar: london).nextNap, "Asleep")
    XCTAssertEqual(GlanceSnapshot.make(babyName: "Nico", asleep: false, napAt: now - 1, lastFeed: nil, lastNappy: nil, sleepMinutesToday: 0, now: now, calendar: london).nextNap, "Offer a nap")
    XCTAssertEqual(GlanceSnapshot.make(babyName: "Nico", asleep: false, napAt: nil, lastFeed: nil, lastNappy: nil, sleepMinutesToday: 0, now: now, calendar: london).lastFeed, "No feeds yet")
  }
}
