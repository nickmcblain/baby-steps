import XCTest
@testable import ScrunchCore

final class FreeAllowanceTests: XCTestCase {
  private let everyEntry: [(LogEntry, LogType?)] = [
    (.feed(.breast, side: .left, minutes: 10, amountMl: nil, milk: nil), .feed),
    (.feed(.bottle, side: nil, minutes: nil, amountMl: 120, milk: .formula), .bottle),
    (.nappy(.wet), .nappy),
    (.potty(.dirty), .potty),
    (.sleep(minutes: 45), nil),
    (.tummy(minutes: 5), .tummy),
    (.pump(.left, minutes: 15, amountMl: 80), .pump),
    (.weight(grams: 4200), .growth),
    (.height(cm: 55), .growth),
    (.medicine(title: "Calpol"), .medicine),
    (.activity(title: "Bath", minutes: 10), .activity),
    (.custom(title: "Jabs"), .note),
  ]

  func testEveryLogMapsToOneAllowanceAndSleepToNone() {
    for (entry, type) in everyEntry {
      XCTAssertEqual(FreeAllowance.type(for: entry), type, entry.summary)
    }
  }

  func testFiveFreeThenTheSixthNeedsASubscription() {
    XCTAssertEqual(FreeAllowance.limit, 5)
    for used in 0..<5 { XCTAssertTrue(FreeAllowance.canLog(.nappy, used: used, unlocked: false)) }
    XCTAssertFalse(FreeAllowance.canLog(.nappy, used: 5, unlocked: false))
    XCTAssertTrue(FreeAllowance.canLog(.nappy, used: 5, unlocked: true))
  }

  func testSleepIsAlwaysFree() {
    XCTAssertTrue(FreeAllowance.canLog(nil, used: 1000, unlocked: false))
    let baby = BabyAllowance(babyId: "b1", unlocked: false, used: [.nappy: 5, .feed: 5])
    XCTAssertTrue(baby.canLog(.sleep(minutes: 30), subscribed: false))
    XCTAssertFalse(baby.canLog(.nappy(.wet), subscribed: false))
    XCTAssertTrue(baby.canLog(.nappy(.wet), subscribed: true))
    XCTAssertTrue(baby.canLog(.feed(.bottle, side: nil, minutes: nil, amountMl: 90, milk: .formula), subscribed: false))
  }

  func testHintIsCalmAndOnlyNearTheLimit() {
    XCTAssertNil(FreeAllowance.hint(.feed, used: 0))
    XCTAssertNil(FreeAllowance.hint(.feed, used: 1))
    XCTAssertEqual(FreeAllowance.hint(.feed, used: 2), "3 of 5 free feeds left. Sleep is always free.")
    XCTAssertEqual(FreeAllowance.hint(.nappy, used: 4), "1 of 5 free nappies left. Sleep is always free.")
    XCTAssertNil(FreeAllowance.hint(.nappy, used: 5))
  }

  func testTrialIsUsedOnceAnyAllowanceRunsOut() {
    XCTAssertFalse(FreeAllowance.trialUsed([:]))
    XCTAssertFalse(FreeAllowance.trialUsed([.feed: 4, .nappy: 4]))
    XCTAssertTrue(FreeAllowance.trialUsed([.feed: 4, .nappy: 5]))
  }

  func testPaywallTitle() {
    XCTAssertEqual(FreeAllowance.paywallTitle(.bottle), "You've used your 5 free bottles")
    XCTAssertEqual(FreeAllowance.paywallTitle(nil), "Keep logging with Scrunch")
  }

  func testDecodesConvexAllowanceAndSkipsUnknownTypes() throws {
    let json = """
    {"limit":5,"babies":[{"babyId":"b1","unlocked":false,"used":[{"type":"nappy","used":5},{"type":"future","used":2}]}]}
    """
    let response = try JSONDecoder().decode(AllowanceResponse.self, from: Data(json.utf8))
    XCTAssertEqual(response.babies, [BabyAllowance(babyId: "b1", unlocked: false, used: [.nappy: 5])])
  }

  func testReadsConvexRefusals() {
    XCTAssertEqual(ServerRefusal(errorData: #"{"code":"FREE_LIMIT_REACHED","type":"pump","limit":5}"#), .freeLimit(.pump))
    XCTAssertEqual(ServerRefusal(errorData: #"{"code":"SUBSCRIPTION_REQUIRED"}"#), .subscriptionRequired)
    XCTAssertNil(ServerRefusal(errorData: #""No baby matches that code""#))
    XCTAssertEqual(ServerRefusal.freeLimit(.pump).message, "You've used your 5 free pumping sessions. Subscribe to keep logging them; sleep is always free.")
  }

  func testSharedAllowanceForWidgetsAndSiri() {
    let defaults = UserDefaults(suiteName: "FreeAllowanceTests-\(UUID().uuidString)")!
    var shared = SharedAllowance(babies: ["b1": BabyAllowance(babyId: "b1", unlocked: false, used: [.nappy: 4])])
    shared.save(to: defaults)
    shared = SharedAllowance.load(from: defaults)
    XCTAssertTrue(shared.canLog(.nappy(.wet), babyId: "b1"))
    shared = shared.counting(.nappy(.wet), babyId: "b1")
    XCTAssertFalse(shared.canLog(.nappy(.wet), babyId: "b1"))
    XCTAssertTrue(shared.canLog(.sleep(minutes: 20), babyId: "b1"))
    XCTAssertTrue(shared.canLog(.nappy(.wet), babyId: "unknown"))
    shared.subscribed = true
    XCTAssertTrue(shared.canLog(.nappy(.wet), babyId: "b1"))
  }

  func testHeldLogsUseTheirOwnQueue() {
    let defaults = UserDefaults(suiteName: "FreeAllowanceTests-\(UUID().uuidString)")!
    let held = PendingLogQueue(defaults: defaults, key: PendingLogQueue.heldKey)
    held.enqueue(PendingLog(babyId: "b1", loggedAt: 0, log: .nappy(.wet)))
    XCTAssertEqual(held.all.count, 1)
    XCTAssertTrue(PendingLogQueue(defaults: defaults).all.isEmpty)
  }
}

final class SubscriptionTests: XCTestCase {
  func testRenewalPriceUsesStoreKitPrice() {
    XCTAssertEqual(Subscription.renewalPrice("£2.99", value: 1, unit: .month), "£2.99 a month")
    XCTAssertEqual(Subscription.renewalPrice("£24.99", value: 1, unit: .year), "£24.99 a year")
    XCTAssertEqual(Subscription.renewalPrice("£7.99", value: 3, unit: .month), "£7.99 every 3 months")
  }

  func testCopyNamesWhatStaysFree() {
    for word in ["Sleep logs", "sleep timers", "Live Activity", "export"] {
      XCTAssertTrue(Subscription.alwaysFree.contains(word), word)
    }
    XCTAssertFalse(Subscription.renewalTerms.contains("trial"))
  }

  func testStatusSummary() {
    let end = london.date(from: DateComponents(year: 2026, month: 12, day: 3, hour: 9))!
    var status = SubscriptionStatus(productID: Subscription.monthlyProductID, expiresAt: end, willAutoRenew: true, familyShared: false)
    XCTAssertEqual(status.summary(calendar: london), "Renews on Thursday 3 December")
    XCTAssertEqual(status.planName, "Monthly subscription")
    status.willAutoRenew = false
    XCTAssertEqual(status.summary(calendar: london), "Ends on Thursday 3 December. It won't renew")
    status.familyShared = true
    XCTAssertEqual(status.summary(calendar: london), "Shared with you through Family Sharing")
    status.productID = Subscription.annualProductID
    XCTAssertEqual(status.planName, "Yearly subscription")
  }
}
