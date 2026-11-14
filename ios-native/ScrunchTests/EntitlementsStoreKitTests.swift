import ScrunchCore
import StoreKit
import StoreKitTest
import XCTest
@testable import Scrunch

/// Runs against StoreKit/Scrunch.storekit, so no App Store Connect products are needed.
@MainActor
final class EntitlementsStoreKitTests: XCTestCase {
  private var session: SKTestSession!

  override func setUp() async throws {
    session = try SKTestSession(configurationFileNamed: "Scrunch")
    session.resetToDefaultState()
    session.disableDialogs = true
    session.clearTransactions()
  }

  override func tearDown() async throws {
    session.clearTransactions()
    session = nil
  }

  private func freshEntitlements() async -> Entitlements {
    let entitlements = Entitlements()
    await entitlements.refresh()
    return entitlements
  }

  func testProductsAndTrialComeFromStoreKit() async throws {
    let entitlements = await freshEntitlements()
    XCTAssertEqual(Set(entitlements.products.map(\.id)), Set(Plus.productIDs))
    XCTAssertFalse(entitlements.hasPlus)
    XCTAssertTrue(entitlements.trialEligible)
    XCTAssertEqual(entitlements.trialLength, "2 weeks")
    XCTAssertEqual(entitlements.monthly?.subscription?.introductoryOffer?.paymentMode, .freeTrial)
    XCTAssertNil(entitlements.products.first { $0.id == Plus.annualProductID }?.subscription?.introductoryOffer)
  }

  func testPurchaseStartsTheFreeTrial() async throws {
    let transaction = try await session.buyProduct(identifier: Plus.monthlyProductID)
    let entitlements = await freshEntitlements()

    let status = try XCTUnwrap(entitlements.status)
    XCTAssertTrue(entitlements.hasPlus)
    XCTAssertTrue(status.inTrial)
    XCTAssertTrue(status.willAutoRenew)
    XCTAssertFalse(status.familyShared)
    let trialDays = try XCTUnwrap(status.expiresAt).timeIntervalSince(transaction.purchaseDate) / 86_400
    XCTAssertEqual(trialDays, 14, accuracy: 0.1)
    XCTAssertFalse(entitlements.trialEligible, "One trial per subscription group")
    XCTAssertNil(entitlements.trialLength)
    XCTAssertEqual(entitlements.renewalPrice(for: status), "£2.99 a month")
  }

  func testAnnualPurchaseHasNoTrial() async throws {
    _ = try await session.buyProduct(identifier: Plus.annualProductID)
    let entitlements = await freshEntitlements()
    XCTAssertEqual(entitlements.status?.productID, Plus.annualProductID)
    XCTAssertEqual(entitlements.status?.inTrial, false)
  }

  func testRestoreOnANewDeviceFindsTheSubscription() async throws {
    _ = try await session.buyProduct(identifier: Plus.monthlyProductID)
    // A fresh service reads Transaction.currentEntitlements, as after a reinstall or Restore.
    let entitlements = await freshEntitlements()
    XCTAssertTrue(entitlements.hasPlus)
  }

  func testCancellingDuringTheTrialKeepsAccessUntilItEnds() async throws {
    let transaction = try await session.buyProduct(identifier: Plus.monthlyProductID)
    try session.disableAutoRenewForTransaction(identifier: UInt(transaction.id))
    let entitlements = await freshEntitlements()
    XCTAssertTrue(entitlements.hasPlus)
    XCTAssertEqual(entitlements.status?.willAutoRenew, false)
  }

  func testExpiryRemovesPlus() async throws {
    _ = try await session.buyProduct(identifier: Plus.monthlyProductID)
    try session.expireSubscription(productIdentifier: Plus.monthlyProductID)
    let entitlements = await freshEntitlements()
    XCTAssertFalse(entitlements.hasPlus)
  }

  func testRefundRemovesPlus() async throws {
    let transaction = try await session.buyProduct(identifier: Plus.monthlyProductID)
    try session.refundTransaction(identifier: UInt(transaction.id))
    let entitlements = await freshEntitlements()
    XCTAssertFalse(entitlements.hasPlus)
  }

  func testTrialReminderNeedsOptInAndAutoRenew() async throws {
    UserDefaults.standard.removeObject(forKey: "plus.trialReminderOptIn")
    let end = Date().addingTimeInterval(14 * 86_400)
    let trial = PlusStatus(productID: Plus.monthlyProductID, expiresAt: end, inTrial: true, willAutoRenew: true, familyShared: false)
    let center = UNUserNotificationCenter.current()

    await TrialReminderScheduler.reconcile(status: trial, renewalPrice: "£2.99 a month")
    var pending = await center.pendingNotificationRequests().map(\.identifier)
    XCTAssertFalse(pending.contains(TrialReminder.identifier), "Never scheduled without consent")

    UserDefaults.standard.set(true, forKey: "plus.trialReminderOptIn")
    var cancelled = trial
    cancelled.willAutoRenew = false
    await TrialReminderScheduler.reconcile(status: cancelled, renewalPrice: nil)
    pending = await center.pendingNotificationRequests().map(\.identifier)
    XCTAssertFalse(pending.contains(TrialReminder.identifier), "No reminder when nothing will be charged")
    UserDefaults.standard.removeObject(forKey: "plus.trialReminderOptIn")
  }
}
