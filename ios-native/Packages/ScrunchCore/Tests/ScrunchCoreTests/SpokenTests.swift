import XCTest
@testable import ScrunchCore

final class SpokenTests: XCTestCase {
  func testClock() {
    XCTAssertEqual(Spoken.clock(0), "0 seconds")
    XCTAssertEqual(Spoken.clock(1_000), "1 second")
    XCTAssertEqual(Spoken.clock(65_000), "1 minute 5 seconds")
    XCTAssertEqual(Spoken.clock(120_000), "2 minutes")
    XCTAssertEqual(Spoken.clock(3_725_900), "1 hour 2 minutes 5 seconds")
    XCTAssertEqual(Spoken.clock(-5_000), "0 seconds")
  }

  func testMinutes() {
    XCTAssertEqual(Spoken.minutes(0), "0 minutes")
    XCTAssertEqual(Spoken.minutes(1), "1 minute")
    XCTAssertEqual(Spoken.minutes(59.6), "1 hour")
    XCTAssertEqual(Spoken.minutes(80), "1 hour 20 minutes")
    XCTAssertEqual(Spoken.minutes(121), "2 hours 1 minute")
  }

  func testTimeOfDay() {
    XCTAssertEqual(Spoken.timeOfDay(minutes: 0), "12am")
    XCTAssertEqual(Spoken.timeOfDay(minutes: 570), "9:30am")
    XCTAssertEqual(Spoken.timeOfDay(minutes: 725), "12:05pm")
    XCTAssertEqual(Spoken.timeOfDay(minutes: 1439), "11:59pm")
    XCTAssertEqual(Spoken.timeOfDay(minutes: 1440), "midnight")
  }

  private func day(_ label: String, _ slices: [(Double, Double)]) -> PatternDay {
    PatternDay(dayStartMs: 0, label: label, slices: slices.map { DaySlice(dayStartMs: 0, startMin: $0.0, endMin: $0.1) })
  }

  func testPatternDay() {
    XCTAssertEqual(Spoken.patternDay(day("Mon 3", [])), "Nothing logged")
    XCTAssertEqual(Spoken.patternDay(day("Mon 3", [(60, 125), (600, 600)])), "2 logged, 1 hour 5 minutes in total")
    XCTAssertEqual(Spoken.patternDay(day("Mon 3", [(600, 600)])), "1 logged")
    XCTAssertEqual(Spoken.patternDay(day("Mon 3", [(60, 125)]), timed: false), "1 logged")
  }

  func testPatternSummary() {
    let rows = [day("Mon 3", [(0, 30), (60, 90)]), day("Tue 4", []), day("Wed 5", [(0, 30)])]
    XCTAssertEqual(Spoken.patternSummary(rows), "3 days, 3 logged. Busiest: Mon 3 with 2. 1 day with nothing logged.")
    XCTAssertEqual(Spoken.patternSummary([day("Mon 3", [])]), "1 day, 0 logged.")
  }

  func testDaySummaryUsesUKNouns() {
    XCTAssertEqual(
      Spoken.daySummary(feeds: 1, nappies: 3, sleepMinutes: 380, tummyMinutes: 12),
      "1 feed, 3 nappies, 6 hours 20 minutes of sleep and 12 minutes of tummy time."
    )
    XCTAssertEqual(
      Spoken.daySummary(feeds: 0, nappies: 1, sleepMinutes: 0, tummyMinutes: 0),
      "0 feeds, 1 nappy, 0 minutes of sleep and 0 minutes of tummy time."
    )
  }

  func testWeekDayCountsOnlyThatDayAndSplitsOvernightSleep() {
    let monday = at(2026, 2, 30)
    let tuesday = WeekGrid.addDays(monday, 1, calendar: london)
    let summary = Spoken.weekDay(
      dayStartMs: tuesday,
      sleeps: [(at(2026, 2, 30, 23), at(2026, 2, 31, 2))],
      tummies: [(at(2026, 2, 31, 10), at(2026, 2, 31, 10, 10))],
      markers: [(.feed, at(2026, 2, 31, 6)), (.feed, at(2026, 2, 31, 9)), (.nappy, at(2026, 2, 31, 9)), (.feed, at(2026, 2, 30, 9))],
      calendar: london
    )
    XCTAssertEqual(summary, "2 hours of sleep, 10 minutes of tummy time, 2 feeds, 1 nappy")
    XCTAssertEqual(
      Spoken.weekDay(dayStartMs: WeekGrid.addDays(monday, 3, calendar: london), sleeps: [], tummies: [], markers: [], calendar: london),
      "Nothing logged"
    )
  }
}
