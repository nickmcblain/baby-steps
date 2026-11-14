import XCTest
@testable import ScrunchCore

final class PlusTests: XCTestCase {
  private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    london.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
  }

  func testDurationsReadNaturally() {
    XCTAssertEqual(Plus.duration(value: 14, unit: .day), "14 days")
    XCTAssertEqual(Plus.duration(value: 2, unit: .week), "2 weeks")
    XCTAssertEqual(Plus.duration(value: 1, unit: .week), "1 week")
    XCTAssertEqual(Plus.duration(value: 1, unit: .month), "1 month")
    XCTAssertEqual(Plus.duration(value: 1, unit: .year), "1 year")
  }

  func testRenewalPriceUsesStoreKitPrice() {
    XCTAssertEqual(Plus.renewalPrice("£2.99", value: 1, unit: .month), "£2.99 a month")
    XCTAssertEqual(Plus.renewalPrice("£24.99", value: 1, unit: .year), "£24.99 a year")
    XCTAssertEqual(Plus.renewalPrice("£7.99", value: 3, unit: .month), "£7.99 every 3 months")
  }

  func testCallToActionOnlyPromisesATrialWhenThereIsOne() {
    XCTAssertEqual(Plus.callToAction(trialLength: "2 weeks"), "Try Plus free for 2 weeks")
    XCTAssertEqual(Plus.callToAction(trialLength: nil), "See Scrunch Plus")
  }

  func testFreeTierCoversCoreLogging() {
    let free = Plus.alwaysFree.joined(separator: " ")
    for word in ["feeds", "sleep", "nappies", "Timers", "widgets", "Live Activity", "Reminders", "partner"] {
      XCTAssertTrue(free.contains(word), word)
    }
  }

  func testStatusSummary() {
    let end = date(2026, 12, 3, 9, 30)
    var status = PlusStatus(productID: Plus.monthlyProductID, expiresAt: end, inTrial: true, willAutoRenew: true, familyShared: false)
    XCTAssertEqual(status.summary(calendar: london), "Free trial until Thursday 3 December, then renews")
    XCTAssertEqual(status.planName, "Plus, monthly")
    status.willAutoRenew = false
    XCTAssertEqual(status.summary(calendar: london), "Free trial until Thursday 3 December. It won't renew")
    status.inTrial = false
    status.willAutoRenew = true
    XCTAssertEqual(status.summary(calendar: london), "Renews on Thursday 3 December")
    status.willAutoRenew = false
    XCTAssertEqual(status.summary(calendar: london), "Ends on Thursday 3 December. It won't renew")
    status.familyShared = true
    XCTAssertEqual(status.summary(calendar: london), "Shared with you through Family Sharing")
    XCTAssertEqual(PlusStatus(productID: Plus.annualProductID, expiresAt: nil, inTrial: false, willAutoRenew: true, familyShared: false).planName, "Plus, yearly")
  }

  func testTrialReminderFiresAt10amTwoDaysBefore() {
    let end = date(2026, 12, 3, 21, 15)
    let fire = TrialReminder.fireDate(trialEndsAt: end, now: date(2026, 11, 19), calendar: london)
    XCTAssertEqual(fire, date(2026, 12, 1, 10, 0))
  }

  func testTrialReminderIsSkippedOnceTooLate() {
    let end = date(2026, 12, 3, 21, 15)
    XCTAssertNil(TrialReminder.fireDate(trialEndsAt: end, now: date(2026, 12, 1, 10, 0), calendar: london))
    XCTAssertNil(TrialReminder.fireDate(trialEndsAt: end, now: date(2026, 12, 2), calendar: london))
  }

  func testTrialReminderAcrossTheClocksGoingBack() {
    let end = date(2026, 10, 26, 8, 0)
    XCTAssertEqual(TrialReminder.fireDate(trialEndsAt: end, now: date(2026, 10, 12), calendar: london), date(2026, 10, 24, 10, 0))
  }

  func testTrialReminderCopyIsHonest() {
    let body = TrialReminder.body(trialEndsAt: date(2026, 12, 3, 9), renewalPrice: "£2.99 a month", calendar: london)
    XCTAssertEqual(body, "Your free trial ends on Thursday 3 December. After that, Plus is £2.99 a month unless you cancel. To cancel, use Manage subscription in Scrunch, or Settings > your name > Subscriptions.")
    XCTAssertTrue(TrialReminder.body(trialEndsAt: date(2026, 12, 3, 9), renewalPrice: nil, calendar: london).contains("Plus renews unless you cancel"))
  }
}
