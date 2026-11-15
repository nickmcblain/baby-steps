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

  func testProductsComeFromStoreKitWithNoTrial() async throws {
    let entitlements = await freshEntitlements()
    XCTAssertEqual(Set(entitlements.products.map(\.id)), Set(Subscription.productIDs))
    XCTAssertFalse(entitlements.subscribed)
    for product in entitlements.products {
      XCTAssertNil(product.subscription?.introductoryOffer, product.id)
    }
  }

  func testMonthlyPurchaseSubscribesStraightAway() async throws {
    let transaction = try await session.buyProduct(identifier: Subscription.monthlyProductID)
    let entitlements = await freshEntitlements()

    let status = try XCTUnwrap(entitlements.status)
    XCTAssertTrue(entitlements.subscribed)
    XCTAssertTrue(status.willAutoRenew)
    XCTAssertFalse(status.familyShared)
    let days = try XCTUnwrap(status.expiresAt).timeIntervalSince(transaction.purchaseDate) / 86_400
    XCTAssertGreaterThan(days, 27, "A full paid month, not a trial")
    XCTAssertEqual(entitlements.renewalPrice(for: status), "£2.99 a month")
  }

  func testYearlyPurchase() async throws {
    _ = try await session.buyProduct(identifier: Subscription.yearlyProductID)
    let entitlements = await freshEntitlements()
    XCTAssertEqual(entitlements.status?.productID, Subscription.yearlyProductID)
    XCTAssertEqual(entitlements.status?.planName, "Yearly subscription")
  }

  func testRestoreOnANewDeviceFindsTheSubscription() async throws {
    _ = try await session.buyProduct(identifier: Subscription.monthlyProductID)
    // A fresh service reads Transaction.currentEntitlements, as after a reinstall or Restore.
    let entitlements = await freshEntitlements()
    XCTAssertTrue(entitlements.subscribed)
  }

  func testCancellingKeepsAccessUntilThePeriodEnds() async throws {
    let transaction = try await session.buyProduct(identifier: Subscription.monthlyProductID)
    try session.disableAutoRenewForTransaction(identifier: UInt(transaction.id))
    let entitlements = await freshEntitlements()
    XCTAssertTrue(entitlements.subscribed)
    XCTAssertEqual(entitlements.status?.willAutoRenew, false)
  }

  func testExpiryEndsTheSubscription() async throws {
    _ = try await session.buyProduct(identifier: Subscription.monthlyProductID)
    try session.expireSubscription(productIdentifier: Subscription.monthlyProductID)
    let entitlements = await freshEntitlements()
    XCTAssertFalse(entitlements.subscribed)
  }

  func testRefundEndsTheSubscription() async throws {
    let transaction = try await session.buyProduct(identifier: Subscription.monthlyProductID)
    try session.refundTransaction(identifier: UInt(transaction.id))
    let entitlements = await freshEntitlements()
    XCTAssertFalse(entitlements.subscribed)
  }
}
