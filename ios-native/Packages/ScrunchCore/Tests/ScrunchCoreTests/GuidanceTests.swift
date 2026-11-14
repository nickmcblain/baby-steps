import XCTest
@testable import ScrunchCore

// Expected values come from lib/sleepGoals.test.ts and from running the TS sources in Node.

final class SleepGoalsTests: XCTestCase {
  func rangeAtAgeDays(_ days: Double) -> SleepRange {
    let now = at(2026, 5, 15, 12, 0)
    return SleepGoals.sleepDurationRange(dateOfBirth: now - days * DAY, now: now)
  }

  func test89DaysIsNSFNewborn14To17h() {
    XCTAssertEqual(rangeAtAgeDays(89), SleepRange(lowHours: 14, highHours: 17))
  }

  func test90DaysSwitchesToAASM12To16h() {
    XCTAssertEqual(rangeAtAgeDays(90), SleepRange(lowHours: 12, highHours: 16))
  }

  func test364DaysStaysOn12To16h() {
    XCTAssertEqual(rangeAtAgeDays(364), SleepRange(lowHours: 12, highHours: 16))
  }

  func test365DaysIsToddler11To14h() {
    XCTAssertEqual(rangeAtAgeDays(365), SleepRange(lowHours: 11, highHours: 14))
  }

  func testTypicalCounts() {
    XCTAssertEqual(SleepGoals.typicalFeedCount(dateOfBirth: 0, now: 55 * DAY), 8)
    XCTAssertEqual(SleepGoals.typicalFeedCount(dateOfBirth: 0, now: 56 * DAY), 6)
    XCTAssertEqual(SleepGoals.typicalFeedCount(dateOfBirth: 0, now: 180 * DAY), 5)
    XCTAssertEqual(SleepGoals.typicalNappyCount(dateOfBirth: 0, now: 55 * DAY), 8)
    XCTAssertEqual(SleepGoals.typicalNappyCount(dateOfBirth: 0, now: 56 * DAY), 6)
  }
}

final class ClothingAdviceTests: XCTestCase {
  func advice(_ temp: Double, weight: Double = 6000, ageDays: Double = 200) -> ClothingAdvice {
    Clothing.advice(tempC: temp, dateOfBirth: 0, weightGrams: weight, now: ageDays * DAY)
  }

  func testBands() {
    XCTAssertEqual(advice(15).tog, "2.5 TOG")
    XCTAssertEqual(advice(15).layers, ["Vest", "Sleepsuit", "2.5 TOG bag", "Light cellular blanket if still cool"])
    XCTAssertEqual(advice(17.5).layers, ["Vest", "Sleepsuit", "2.5 TOG sleeping bag"])
    XCTAssertEqual(advice(17.5).why, "On the cool side of the usual 16–20°C range.")
    XCTAssertEqual(advice(19).tog, "1.0 TOG")
    XCTAssertEqual(advice(21).layers, ["Vest", "1.0 TOG bag or light sleepsuit"])
    XCTAssertEqual(advice(23).tog, "0.5 TOG")
    XCTAssertEqual(advice(25).tog, "0.2 TOG")
    XCTAssertEqual(advice(25).why, "At 24°C and above, babies overheat easily. Less is safer.")
  }

  func testBandEdgesAreExclusive() {
    XCTAssertEqual(advice(16).tog, "2.5 TOG")
    XCTAssertEqual(advice(18).tog, "1.0 TOG")
    XCTAssertEqual(advice(24).tog, "0.2 TOG")
  }

  func testOverheat() {
    XCTAssertFalse(advice(21.5).overheat)
    XCTAssertTrue(advice(22).overheat)
  }

  func testYoungOrLightBabyGetsAnExtraLayer() {
    let young = advice(19, weight: 4000, ageDays: 30)
    XCTAssertTrue(young.extraLayer)
    XCTAssertEqual(young.layers, ["Extra vest (newborn / smaller baby)", "Vest", "Sleepsuit or 1.0 TOG bag"])
    XCTAssertEqual(
      young.why,
      "This is the typical comfortable nursery band. Under 3 months or a lighter baby can use one extra thin layer — never a hat indoors."
    )
    XCTAssertTrue(advice(19, weight: 4999, ageDays: 200).extraLayer)
    XCTAssertTrue(advice(19, weight: 6000, ageDays: 91).extraLayer)
    XCTAssertFalse(advice(19, weight: 6000, ageDays: 92).extraLayer)
  }

  func testNoExtraLayerAt24AndAbove() {
    let hot = advice(24, weight: 3000, ageDays: 10)
    XCTAssertTrue(hot.extraLayer)
    XCTAssertEqual(hot.layers, ["Nappy", "Short-sleeve vest if needed"])
  }

  func testTempFormattingAndNudge() {
    XCTAssertEqual(Clothing.formatTemp(18, fahrenheit: false), "18")
    XCTAssertEqual(Clothing.formatTemp(18.5, fahrenheit: false), "18.5")
    XCTAssertEqual(Clothing.formatTemp(20, fahrenheit: true), "68")
    XCTAssertEqual(Clothing.formatTemp(18.5, fahrenheit: true), "65.3")
    XCTAssertEqual(Clothing.nudge(18, by: 0.5), 18.5)
    XCTAssertEqual(Clothing.nudge(40, by: 0.5), 40)
    XCTAssertEqual(Clothing.nudge(5, by: -0.5), 5)
  }
}

final class FeedWindowsTests: XCTestCase {
  func window(_ days: Double, _ weight: Double, _ mode: FeedingMode?) -> FeedWindow {
    FeedWindows.window(dateOfBirth: 0, weightGrams: weight, feedingMode: mode, now: days * DAY)
  }

  func testWindowsByAgeAndMode() {
    XCTAssertEqual(window(10, 4000, nil), FeedWindow(
      intervalMs: 9_000_000, label: "about 2.5 hours", shouldWakeForFeeds: true,
      reason: "Under 8 weeks — feed check-ins stay on even if they're asleep."
    ))
    XCTAssertEqual(window(10, 4000, .bottle).intervalMs, 10_800_000)
    XCTAssertEqual(window(10, 4000, .bottle).label, "about 3 hours")
    XCTAssertEqual(window(60, 6000, .mixed), FeedWindow(
      intervalMs: 12_600_000, label: "about 3.5 hours", shouldWakeForFeeds: false,
      reason: "At this age and weight, an active sleep timer pauses feed reminders so you can leave them sleeping."
    ))
    XCTAssertEqual(window(100, 6000, .bottle).intervalMs, 13_500_000)
    XCTAssertEqual(window(200, 8000, nil).intervalMs, 14_400_000)
    XCTAssertEqual(window(200, 8000, nil).label, "about 4 hours")
  }

  func testLightBabyStillGetsWoken() {
    let w = window(60, 4500, nil)
    XCTAssertTrue(w.shouldWakeForFeeds)
    XCTAssertEqual(w.reason, "Under 5 kg — feed check-ins stay on even if they're asleep.")
  }

  func testFeedEndedAtAddsDuration() {
    let event = Event(loggedAt: 1_000_000, kind: .feed, durationMinutes: 15)
    XCTAssertEqual(FeedWindows.feedEndedAt(event), 1_000_000 + 15 * 60_000)
  }
}

final class GrowthLMSTests: XCTestCase {
  func testValueFromZ() {
    XCTAssertEqual(GrowthLMS.valueFromZ(.weight, sex: .boy, month: 6, z: 0)!, 7.934, accuracy: 1e-9)
    XCTAssertEqual(GrowthLMS.valueFromZ(.length, sex: .girl, month: 3.5, z: 1.34076)!, 63.80885876909792, accuracy: 1e-9)
  }

  func testZScore() {
    XCTAssertEqual(GrowthLMS.zScore(.weight, sex: .boy, month: 2, value: 4.0)!, -2.5846811798739635, accuracy: 1e-9)
    XCTAssertNil(GrowthLMS.zScore(.weight, sex: .boy, month: 2, value: 0))
  }

  func testCentileFromZ() {
    XCTAssertEqual(GrowthLMS.centileFromZ(0), 49.999985009951, accuracy: 1e-9)
    XCTAssertEqual(GrowthLMS.centileFromZ(1.34076), 91.00007608454686, accuracy: 1e-9)
    XCTAssertEqual(GrowthLMS.centileFromZ(-2.65207), 0.40000396413473005, accuracy: 1e-9)
    XCTAssertEqual(GrowthLMS.centileFromZ(3), 99.86500329080518, accuracy: 1e-9)
  }

  func testFormatCentile() {
    XCTAssertEqual([50, 1.2, 11, 22, 0.5, 99.4, 3].map(GrowthLMS.formatCentile), ["50th", "1st", "11th", "22nd", "0.5th", "99.4th", "3rd"])
  }

  func testBands() {
    XCTAssertEqual([-2.1, -1.5, 0, 1.5, 2.2].map { GrowthLMS.band($0) }, [.veryLow, .low, .typical, .high, .veryHigh])
    XCTAssertEqual(GrowthLMS.band(nil), .unknown)
  }

  func testMaxChartMonths() {
    let month = 30.4375 * DAY
    XCTAssertEqual(GrowthLMS.maxChartMonths(dateOfBirth: 0, now: 2 * month), 6)
    XCTAssertEqual(GrowthLMS.maxChartMonths(dateOfBirth: 0, now: 10.2 * month), 12)
    XCTAssertEqual(GrowthLMS.maxChartMonths(dateOfBirth: 0, now: 40 * month), 24)
  }

  func testTablesCoverZeroTo24Months() {
    for table in [WHOLMSData.weight, WHOLMSData.length] {
      for sex in Sex.allCases {
        XCTAssertEqual(table[sex]?.count, 25)
        XCTAssertEqual(table[sex]?.first?.month, 0)
        XCTAssertEqual(table[sex]?.last?.month, 24)
      }
    }
  }

  func testLatestStatus() {
    let month = 30.4375 * DAY
    let status = GrowthLMS.latestStatus(.weight, sex: .boy, dateOfBirth: 0, latest: GrowthPoint(at: 6 * month, value: 7.934))
    XCTAssertEqual(status?.text, "Latest ≈ 50th centile · Within expected range")
    XCTAssertEqual(status?.band, .typical)
  }
}
