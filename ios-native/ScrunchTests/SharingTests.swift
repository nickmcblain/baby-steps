import ScrunchCore
import StoreKitTest
import XCTest
@testable import Scrunch

/// Sharing a baby needs each carer's own subscription: creating a code and joining with one.
@MainActor
final class SharingTests: XCTestCase {
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

  private func freshGate() async -> SharingGate {
    let entitlements = Entitlements()
    await entitlements.refresh()
    return SharingGate(entitlements: entitlements)
  }

  private func waitForPaywall(_ gate: SharingGate) async throws -> SharingGate.Reason {
    for _ in 0..<100 {
      if let paywall = gate.paywall { return paywall }
      try await Task.sleep(for: .milliseconds(20))
    }
    return try XCTUnwrap(gate.paywall)
  }

  private func subscribe(_ gate: SharingGate) async throws {
    _ = try await session.buyProduct(identifier: Subscription.monthlyProductID)
    let entitlements = try XCTUnwrap(gate.entitlements)
    for _ in 0..<50 where !entitlements.subscribed {
      await entitlements.refresh()
      try await Task.sleep(for: .milliseconds(100))
    }
    XCTAssertTrue(entitlements.subscribed)
  }

  func testJoiningWithoutASubscriptionShowsThePaywallThenJoinsWithTheSameCode() async throws {
    let gate = await freshGate()
    let redeemed = Codes()
    let pending = Task { try await gate.perform(.join) { redeemed.list.append("P8GU2T"); return "b1" } }
    let reason = try await waitForPaywall(gate)
    XCTAssertEqual(reason, .join)
    XCTAssertEqual(redeemed.list, [], "Nothing is sent before they subscribe")

    try await subscribe(gate)
    gate.paywallClosed()
    let joined = try await pending.value
    XCTAssertEqual(joined, "b1")
    XCTAssertEqual(redeemed.list, ["P8GU2T"])
  }

  func testClosingThePaywallJoinsNothing() async throws {
    let gate = await freshGate()
    let redeemed = Codes()
    let pending = Task { try await gate.perform(.join) { redeemed.list.append("P8GU2T"); return "b1" } }
    _ = try await waitForPaywall(gate)
    gate.paywallClosed()
    let joined = try await pending.value
    XCTAssertNil(joined)
    XCTAssertEqual(redeemed.list, [])
  }

  func testCreatingACodeNeedsASubscription() async throws {
    let gate = await freshGate()
    let pending = Task { try await gate.perform(.invite) { "P8GU2T" } }
    let reason = try await waitForPaywall(gate)
    XCTAssertEqual(reason, .invite)
    gate.paywallClosed()
    let code = try await pending.value
    XCTAssertNil(code)
  }

  func testASubscribedCarerSharesStraightAway() async throws {
    let gate = await freshGate()
    try await subscribe(gate)
    let code = try await gate.perform(.invite) { "P8GU2T" }
    XCTAssertEqual(code, "P8GU2T")
    XCTAssertNil(gate.paywall)
  }

  func testIfConvexHasntSeenThePurchaseYetItResyncsAndRetries() async throws {
    let gate = await freshGate()
    try await subscribe(gate)
    let attempts = Codes()
    let joined = try await gate.perform(.join) { () throws -> BabyID in
      attempts.list.append("try")
      if attempts.list.count == 1 { throw ServerRefusal.sharingNeedsSubscription }
      return "b1"
    }
    XCTAssertEqual(joined, "b1")
    XCTAssertEqual(attempts.list.count, 2)
    XCTAssertNil(gate.paywall)
  }

  func testAnotherAccountsPurchaseOnThisAppleIDDoesntCount() async throws {
    let entitlements = Entitlements()
    entitlements.appAccountToken = UUID()
    _ = try await session.buyProduct(identifier: Subscription.monthlyProductID, options: [.appAccountToken(UUID())])
    await entitlements.refresh()
    XCTAssertFalse(entitlements.subscribed, "Entitlement is per carer")

    session.clearTransactions()
    _ = try await session.buyProduct(identifier: Subscription.monthlyProductID, options: [.appAccountToken(entitlements.appAccountToken!)])
    for _ in 0..<50 where !entitlements.subscribed {
      await entitlements.refresh()
      try await Task.sleep(for: .milliseconds(100))
    }
    XCTAssertTrue(entitlements.subscribed)
  }

  func testFamilySharingIsOff() async throws {
    let entitlements = Entitlements()
    await entitlements.refresh()
    let product = try XCTUnwrap(entitlements.products.first)
    XCTAssertFalse(product.isFamilyShareable)
  }

  func testSharingCopyComesFromTheStringCatalog() {
    XCTAssertEqual(SharingCopy.eachCarer, "Each carer needs their own Scrunch subscription to share a baby.")
    XCTAssertEqual(SharingCopy.paywallTitle, "Sharing comes with a subscription")
    XCTAssertEqual(SharingCopy.joinSubtitle, "Subscribe and you'll join straight away with the code you entered.")
    XCTAssertEqual(SharingCopy.inviteSubtitle, "Subscribe and you'll get a code to send to your partner or carer.")
    XCTAssertEqual(SharingCopy.subscribeAndJoin, "Subscribe and join")
  }
}

private final class Codes: @unchecked Sendable {
  var list: [String] = []
}
