import XCTest
@testable import ScrunchCore

// Port of lib/sleepOffer.test.ts.
final class SleepOfferTests: XCTestCase {
  func seg(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ durationMinutes: Double) -> SleepSegment {
    let startMs = at(year, month, day, hour, minute)
    return SleepSegment(startMs: startMs, endMs: startMs + durationMinutes * 60_000, durationMinutes: durationMinutes)
  }

  /// Three days of night + two day naps. Morning wake 90m, inter-nap 75m.
  func threeDayPattern() -> [SleepSegment] {
    var sleeps: [SleepSegment] = []
    for d in [10, 11, 12] {
      sleeps.append(seg(2026, 5, d - 1, 20, 0, 600))
      sleeps.append(seg(2026, 5, d, 7, 30, 60))
      sleeps.append(seg(2026, 5, d, 9, 45, 60))
    }
    return sleeps
  }

  // MARK: daytimeWakeGaps

  func testIncludesNightToFirstDayNapAndNapToNap() {
    let gaps = SleepOffer.daytimeWakeGaps([
      seg(2026, 5, 10, 20, 0, 600),
      seg(2026, 5, 11, 7, 30, 60),
      seg(2026, 5, 11, 9, 45, 60),
    ], calendar: london)
    XCTAssertEqual(gaps.map { $0.gapMs / 60_000 }, [90, 75])
  }

  func testExcludesLastNapToNight() {
    XCTAssertEqual(SleepOffer.daytimeWakeGaps([
      seg(2026, 5, 11, 16, 0, 60),
      seg(2026, 5, 11, 19, 30, 600),
    ], calendar: london), [])
  }

  func testSkipsGapsUnder15Minutes() {
    XCTAssertEqual(SleepOffer.daytimeWakeGaps([
      seg(2026, 5, 11, 8, 0, 30),
      seg(2026, 5, 11, 8, 40, 30),
    ], calendar: london), [])
  }

  // MARK: personalWakeGap

  func testEnoughDayGapsGivesMedianRoundedTo5Minutes() {
    // 90, 75, 90, 75, 90, 75 → median 82.5 → 85
    XCTAssertEqual(SleepOffer.personalWakeGap(threeDayPattern(), calendar: london), 85 * 60_000)
  }

  func testSparseDataIsNotEnough() {
    XCTAssertNil(SleepOffer.personalWakeGap([
      seg(2026, 5, 10, 20, 0, 600),
      seg(2026, 5, 11, 7, 30, 60),
      seg(2026, 5, 11, 9, 45, 60),
    ], calendar: london))
  }

  func testWithTenPlusGapsDropsTheLongest10Percent() {
    var sleeps: [SleepSegment] = []
    for d in 1...10 {
      sleeps.append(seg(2026, 5, d - 1, 20, 0, 600))
      sleeps.append(d == 10 ? seg(2026, 5, d, 12, 0, 60) : seg(2026, 5, d, 7, 0, 60))
    }
    XCTAssertEqual(SleepOffer.personalWakeGap(sleeps, calendar: london), 60 * 60_000)
  }

  // MARK: predictedNapAt

  func testLastWakePlusPersonalMedianGap() {
    let pattern = threeDayPattern()
    let last = pattern.last!
    XCTAssertEqual(SleepOffer.predictedNapAt(sleeps: pattern, lastSleepEndMs: last.endMs, calendar: london), last.endMs + 85 * 60_000)
  }

  func testNilWithoutEnoughPatternOrLastWake() {
    let pattern = threeDayPattern()
    let last = pattern.last!
    XCTAssertNil(SleepOffer.predictedNapAt(sleeps: Array(pattern.prefix(3)), lastSleepEndMs: last.endMs, calendar: london))
    XCTAssertNil(SleepOffer.predictedNapAt(sleeps: pattern, lastSleepEndMs: nil, calendar: london))
  }

  // MARK: predictedNapLabel

  func label(_ sleeps: [SleepSegment], lastEnd: EpochMs?, lastMinutes: Double?, asleep: Bool, now: EpochMs) -> NapOffer {
    SleepOffer.predictedNapLabel(sleeps: sleeps, lastSleepEndMs: lastEnd, lastSleepMinutes: lastMinutes, asleep: asleep, now: now, calendar: london)
  }

  func testAsleepHidesAnOffer() {
    let pattern = threeDayPattern()
    let last = pattern.last!
    XCTAssertEqual(
      label(pattern, lastEnd: last.endMs, lastMinutes: last.durationMinutes, asleep: true, now: last.endMs + 10 * 60_000),
      NapOffer(label: "Asleep", subline: "")
    )
  }

  func testEnoughPatternOffersAroundLastWakePlusMedian() {
    let pattern = threeDayPattern()
    let last = pattern.last!
    let offer = label(pattern, lastEnd: last.endMs, lastMinutes: last.durationMinutes, asleep: false, now: last.endMs + 10 * 60_000)
    // 10:45 + 85m = 12:10
    XCTAssertEqual(offer, NapOffer(label: "Often ready around 12:10", subline: "From their last two weeks"))
  }

  func testPastTheUsualGapSaysOfferANap() {
    let pattern = threeDayPattern()
    let last = pattern.last!
    XCTAssertEqual(
      label(pattern, lastEnd: last.endMs, lastMinutes: last.durationMinutes, asleep: false, now: last.endMs + 3 * 60 * 60_000),
      NapOffer(label: "Offer a nap", subline: "A guess from their usual gap. Cues first.")
    )
  }

  func testShortLastNapDoesNotFallBackToAnAgeBandClock() {
    let pattern = threeDayPattern()
    let last = pattern.last!
    let offer = label(pattern, lastEnd: last.endMs, lastMinutes: 20, asleep: false, now: last.endMs + 10 * 60_000)
    XCTAssertTrue(offer.label.hasPrefix("Often ready around"))
    XCTAssertEqual(offer.subline, "A short nap still counts.")
  }

  func testSparseLogsShowCuesNotAMadeUpDueTime() {
    XCTAssertEqual(
      label([seg(2026, 5, 11, 8, 0, 60)], lastEnd: at(2026, 5, 11, 9, 0), lastMinutes: 60, asleep: false, now: at(2026, 5, 11, 10, 0)),
      NapOffer(label: "Watch cues", subline: "Not enough of a daytime pattern yet.")
    )
  }
}
