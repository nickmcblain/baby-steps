import XCTest
@testable import ScrunchCore

/// Units and dates follow the locale: en-GB for 1.0, en-US and en-AU for later launches.
/// ICU puts a narrow no-break space (U+202F) before AM/PM.
final class LocaleFormattingTests: XCTestCase {
  let us = display("en_US")
  let au = display("en_AU")

  func testUnitsFollowMeasurementSystem() {
    XCTAssertEqual(gb.weightUnit, .kg)
    XCTAssertEqual(au.weightUnit, .kg)
    XCTAssertEqual(us.weightUnit, .lb)
    XCTAssertEqual(gb.heightUnit, .cm)
    XCTAssertEqual(au.heightUnit, .cm)
    XCTAssertEqual(us.heightUnit, .inches)
    XCTAssertEqual(gb.volumeUnit, .milliliters)
    XCTAssertEqual(au.volumeUnit, .milliliters)
    XCTAssertEqual(us.volumeUnit, .fluidOunces)
    XCTAssertEqual(gb.temperatureUnit, .celsius)
    XCTAssertEqual(au.temperatureUnit, .celsius)
    XCTAssertEqual(us.temperatureUnit, .fahrenheit)
  }

  func testWeight() {
    XCTAssertEqual(gb.weight(6500), "6.5 kg")
    XCTAssertEqual(au.weight(6500), "6.5 kg")
    XCTAssertEqual(us.weight(6500), "14 lb 5 oz")
  }

  func testWeightPreferenceOverridesRegion() {
    XCTAssertEqual(display("en_GB", weight: .lbOz).weight(6500), "14 lb 5 oz")
    XCTAssertEqual(display("en_US", weight: .kg).weight(6500), "6.5 kg")
    XCTAssertEqual(display("en_GB", weight: .lbOz).weightUnit, .lb)
  }

  func testLength() {
    XCTAssertEqual(gb.length(50.5), "50.5 cm")
    XCTAssertEqual(au.length(50.5), "50.5 cm")
    XCTAssertEqual(us.length(50.5), "1′ 8″")
  }

  func testVolume() {
    XCTAssertEqual(gb.volume(120), "120 ml")
    XCTAssertEqual(gb.volumeSymbol, "ml")
    XCTAssertEqual(au.volume(120), "120 mL")
    XCTAssertEqual(us.volume(120), "4.1 fl oz")
    XCTAssertEqual(gb.millilitres(fromInput: 90), 90)
    XCTAssertEqual(us.millilitres(fromInput: 4), 118)
  }

  func testIntentSummariesFollowRegion() {
    let bottle = LogEntry.feed(.bottle, side: nil, minutes: nil, amountMl: 120, milk: nil)
    XCTAssertEqual(bottle.summary(format: gb), "Bottle · 120 ml")
    XCTAssertEqual(bottle.summary(format: us), "Bottle · 4.1 fl oz")
    XCTAssertEqual(LogEntry.height(cm: 55).summary(format: au), "Height · 55 cm")
  }

  func testTemperature() {
    XCTAssertEqual(gb.temperature(18), "18°C")
    XCTAssertEqual(au.temperature(18.5), "18.5°C")
    XCTAssertEqual(us.temperature(18), "64.4°F")
  }

  func testTimeFollowsHourCycle() {
    let afternoon = at(2026, 7, 20, 14, 5)
    XCTAssertTrue(gb.uses24HourClock)
    XCTAssertFalse(us.uses24HourClock)
    XCTAssertEqual(gb.time(afternoon), "14:05")
    XCTAssertEqual(us.time(afternoon), "2:05\u{202F}PM")
    XCTAssertEqual(au.time(afternoon), "2:05\u{202F}pm")
  }

  func testDeviceTwelveHourSettingWinsOverRegion() {
    // iOS's 24-Hour Time switch reaches Locale as an hour-cycle override.
    let twelveHourGB = DisplayFormat(calendar: calendar("en_GB@hours=h12"), weightPreference: .automatic)
    XCTAssertFalse(twelveHourGB.uses24HourClock)
    XCTAssertEqual(twelveHourGB.time(at(2026, 7, 20, 14, 5)), "2:05\u{202F}pm")
    let twentyFourHourUS = DisplayFormat(calendar: calendar("en_US@hours=h23"), weightPreference: .automatic)
    XCTAssertEqual(twentyFourHourUS.time(at(2026, 7, 20, 14, 5)), "14:05")
  }

  func testHourLabels() {
    XCTAssertEqual([0, 6, 15].map(gb.hourLabel), ["00", "06", "15"])
    XCTAssertEqual([0, 6, 15].map(us.hourLabel), ["12\u{202F}AM", "6\u{202F}AM", "3\u{202F}PM"])
  }

  func testDates() {
    let day = at(2026, 0, 3, 9)
    XCTAssertEqual(gb.date(day), "3 Jan 2026")
    XCTAssertEqual(au.date(day), "3 Jan 2026")
    XCTAssertEqual(us.date(day), "Jan 3, 2026")
    XCTAssertEqual(gb.dayMonthTime(at(2026, 7, 20, 14, 30)), "20 Aug · 14:30")
    XCTAssertEqual(us.dayMonthTime(at(2026, 7, 20, 14, 30)), "Aug 20 · 2:30\u{202F}PM")
    XCTAssertEqual(Format.dob(Format.dobMs(year: 2026, month: 1, day: 3), calendar: calendar("en_US")), "Jan 3, 2026")
    XCTAssertEqual(gb.weekdayDate(at(2026, 10, 16, 9), now: at(2026, 10, 16, 15)), "Monday 16 November")
    XCTAssertEqual(us.weekdayDate(at(2026, 10, 16, 9), now: at(2026, 10, 16, 15)), "Monday, November 16")
    XCTAssertEqual(gb.weekdayDate(at(2025, 10, 7, 9), now: at(2026, 10, 16, 15)), "Friday, 7 November 2025")
  }

  func testWeekRange() {
    XCTAssertEqual(WeekGrid.formatWeekRange(at(2026, 7, 3), calendar: calendar("en_US")), "Aug 3\u{2009}–\u{2009}9")
    XCTAssertEqual(WeekGrid.formatWeekRange(at(2026, 7, 3), calendar: calendar("en_AU")), "3\u{2009}–\u{2009}9 Aug")
  }

  func testDurationsAreTheSameInEveryEnglish() {
    for format in [gb, us, au] {
      XCTAssertEqual(format.duration(minutes: 45), "45 min")
      XCTAssertEqual(format.duration(minutes: 95), "1h 35m")
    }
  }

  func testEventTitlesUseTheRegionsUnits() {
    let bottle = Event(loggedAt: 0, kind: .feed, feedKind: .bottle, amountMl: 120, milk: .formula)
    XCTAssertEqual(EventCopy.title(bottle, format: gb), "120 ml Formula")
    XCTAssertEqual(EventCopy.title(bottle, format: us), "4.1 fl oz Formula")
    let weighIn = Event(loggedAt: 0, kind: .weight, weightGrams: 6500)
    XCTAssertEqual(EventCopy.title(weighIn, format: display("en_GB", weight: .lbOz)), "14 lb 5 oz")
  }

  func testPluralAges() {
    XCTAssertEqual(Format.age(dateOfBirth: 0, now: DAY), "1 day")
    XCTAssertEqual(Format.age(dateOfBirth: 0, now: 2 * DAY), "2 days")
    XCTAssertEqual(Format.age(dateOfBirth: 0, now: 14 * DAY), "2 weeks")
  }
}

final class HealthRegionTests: XCTestCase {
  func testUKWording() {
    let uk = HealthRegion.uk
    XCTAssertTrue(uk.emergencyBody.contains("999"))
    XCTAssertTrue(uk.askDisclaimer.contains("NHS 111"))
    XCTAssertTrue(uk.growthChartSource.contains("UK-WHO"))
    XCTAssertTrue(uk.growthOutsideRangeCaution.contains("health visitor"))
    XCTAssertEqual(AskSafety.disclaimer, uk.askDisclaimer)
    XCTAssertEqual(GrowthLMS.outsideRangeCaution, uk.growthOutsideRangeCaution)
  }
}

final class UKWHOTests: XCTestCase {
  let month = 30.4375 * DAY

  func testBirthUsesUK90TermCentiles() {
    XCTAssertEqual(GrowthLMS.valueFromZ(.weight, sex: .boy, month: 0, z: 0)!, 3.5551, accuracy: 1e-9)
    XCTAssertEqual(GrowthLMS.valueFromZ(.weight, sex: .girl, month: 0, z: 0)!, 3.413, accuracy: 1e-9)
    XCTAssertEqual(GrowthLMS.valueFromZ(.length, sex: .boy, month: 0, z: 0)!, 50.94454, accuracy: 1e-9)
  }

  func testNoCentilesBetweenBirthAndTwoWeeks() {
    XCTAssertNil(GrowthLMS.valueFromZ(.weight, sex: .boy, month: 7 / 30.4375, z: 0))
    XCTAssertNil(GrowthLMS.latestStatus(.weight, sex: .girl, dateOfBirth: 0, latest: GrowthPoint(at: 5 * DAY, value: 3.2)))
    XCTAssertNotNil(GrowthLMS.valueFromZ(.weight, sex: .boy, month: 14 / 30.4375, z: 0))
  }

  func testFromTwoWeeksUsesWHO2006() {
    XCTAssertEqual(GrowthLMS.valueFromZ(.weight, sex: .boy, month: 1, z: 0)!, 4.4709, accuracy: 1e-9)
    XCTAssertEqual(GrowthLMS.valueFromZ(.length, sex: .girl, month: 12, z: 0)!, 74.015, accuracy: 1e-9)
  }
}
