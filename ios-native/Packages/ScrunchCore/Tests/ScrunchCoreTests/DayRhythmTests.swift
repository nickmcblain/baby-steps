import XCTest
@testable import ScrunchCore

// Port of lib/dayRhythm.test.ts.
final class DayRhythmTests: XCTestCase {
  func sleepMinutes(_ segments: [RhythmSegment]) -> Double {
    segments.filter { $0.kind != .awake }.reduce(0) { $0 + ($1.end - $1.start) }
  }

  func rhythmAtAge(_ days: Double, _ sleeps: [RhythmSleep] = [], night: NightWindow? = nil) -> DayRhythm {
    let now = at(2026, 7, 15, 12)
    return DayRhythmEngine.recommendedDay(dateOfBirth: now - days * DAY, now: now, sleeps: sleeps, night: night, calendar: london)
  }

  func testNewbornWithNoLogsIsAn18hNHSBurstShape() {
    let day = rhythmAtAge(10)
    XCTAssertEqual(day.source, .nhs)
    XCTAssertEqual(sleepMinutes(day.segments), 18 * 60)
    XCTAssertEqual(day.segments.reduce(0) { $0 + ($1.end - $1.start) }, 1440)
  }

  func testSixToTwelveMonthsNHSShapeIs15hWithA12hNight() {
    let day = rhythmAtAge(200)
    XCTAssertEqual(day.source, .nhs)
    XCTAssertEqual(sleepMinutes(day.segments), 15 * 60)
    let night = day.segments.first { $0.kind == .night }
    XCTAssertEqual(night.map { $0.end - $0.start }, 12 * 60)
  }

  func testThreeSimilarNightsBeatTheNHSShape() {
    let sleeps = [1, 2, 3].map { day in
      RhythmSleep(startMs: at(2026, 7, day, 19, 0), endMs: at(2026, 7, day + 1, 7, 0))
    }
    let day = rhythmAtAge(200, sleeps)
    XCTAssertEqual(day.source, .logs)
    XCTAssertEqual(day.segments.first { $0.kind == .night }, RhythmSegment(start: 12 * 60, end: 1440, kind: .night))
  }

  func testNineWeekOldWithASetNightGetsOneBlockInsteadOfBursts() {
    let day = rhythmAtAge(63, night: NightWindow(bedMin: 19 * 60, wakeMin: 7 * 60))
    XCTAssertEqual(day.segments.filter { $0.kind == .night }, [RhythmSegment(start: 12 * 60, end: 1440, kind: .night)])
    XCTAssertEqual(day.segments.filter { $0.kind == .nap }.count, 3)
  }

  func testWakeAfter7amContinuesTheNightIntoTheMorning() {
    let day = rhythmAtAge(63, night: NightWindow(bedMin: 19 * 60, wakeMin: 8 * 60))
    XCTAssertEqual(day.segments.filter { $0.kind == .night }, [
      RhythmSegment(start: 0, end: 60, kind: .night),
      RhythmSegment(start: 12 * 60, end: 1440, kind: .night),
    ])
  }

  func testCountdownIsTheNextShadedBlockOrNowWhenAlreadyInsideOne() {
    let segments = [
      RhythmSegment(start: 0, end: 180, kind: .nap),
      RhythmSegment(start: 240, end: 420, kind: .nap),
      RhythmSegment(start: 720, end: 1440, kind: .night),
    ]
    XCTAssertEqual(
      DayRhythmEngine.nextSleepCountdown(segments, now: at(2026, 7, 15, 10, 30), calendar: london),
      SleepCountdown(inMs: 30 * 60_000, kind: .nap)
    )
    XCTAssertEqual(
      DayRhythmEngine.nextSleepCountdown(segments, now: at(2026, 7, 15, 12, 0), calendar: london),
      SleepCountdown(inMs: 0, kind: .nap)
    )
    XCTAssertEqual(
      DayRhythmEngine.nextSleepCountdown([RhythmSegment(start: 60, end: 180, kind: .nap)], now: at(2026, 7, 15, 6, 30), calendar: london),
      SleepCountdown(inMs: 90 * 60_000, kind: .nap)
    )
  }

  func testOneLoggedNightIsNotAPattern() {
    let day = rhythmAtAge(200, [RhythmSleep(startMs: at(2026, 7, 1, 19, 0), endMs: at(2026, 7, 2, 7, 0))])
    XCTAssertEqual(day.source, .nhs)
  }

  // Additional coverage beyond the TS suite.

  func testCaptionsByAge() {
    XCTAssertEqual(rhythmAtAge(10).caption, "About 18h in short bursts. NHS, not a timetable.")
    XCTAssertEqual(rhythmAtAge(100).caption, "A longer night may start now. NHS, not a timetable.")
    XCTAssertEqual(rhythmAtAge(200).caption, "About 15h, mostly at night. NHS, not a timetable.")
    XCTAssertEqual(rhythmAtAge(400).caption, "About 12–15h, with a daytime nap. NHS, not a timetable.")
    XCTAssertEqual(rhythmAtAge(800).caption, "About 12–14h, nap included. NHS, not a timetable.")
    XCTAssertEqual(
      rhythmAtAge(63, night: .default).caption,
      "Night you set. Daytime naps still follow the age shape."
    )
  }

  func testInvalidNightIsIgnored() {
    // 2h night is shorter than the 4h minimum.
    let day = rhythmAtAge(200, night: NightWindow(bedMin: 19 * 60, wakeMin: 21 * 60))
    XCTAssertEqual(day.caption, "About 15h, mostly at night. NHS, not a timetable.")
  }

  func testSegmentsAlwaysCoverTheWholeDay() {
    for age in [10.0, 100, 200, 400, 800] {
      let segments = rhythmAtAge(age).segments
      XCTAssertEqual(segments.first?.start, 0)
      XCTAssertEqual(segments.last?.end, 1440)
      for (a, b) in zip(segments, segments.dropFirst()) {
        XCTAssertEqual(a.end, b.start)
      }
    }
  }

  func testRhythmFromLogsAcrossTheBSTChange() {
    // Nights spanning the 29 Mar 2026 clock change still read as a 19:00 night.
    let sleeps = [27, 28, 29].map { day in
      RhythmSleep(startMs: at(2026, 2, day, 19, 0), endMs: at(2026, 2, day + 1, 7, 0))
    }
    let now = at(2026, 2, 31, 12)
    let day = DayRhythmEngine.recommendedDay(dateOfBirth: now - 200 * DAY, now: now, sleeps: sleeps, calendar: london)
    XCTAssertEqual(day.source, .logs)
    XCTAssertEqual(day.segments.first { $0.kind == .night }?.start, 12 * 60)
  }
}
