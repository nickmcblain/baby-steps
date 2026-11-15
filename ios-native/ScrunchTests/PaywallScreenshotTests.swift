import ScrunchCore
import StoreKitTest
import SwiftUI
import XCTest
@testable import Scrunch

/// Renders the paywall screens against StoreKit/Scrunch.storekit and attaches PNGs to the test
/// result, for App Review and PR screenshots. Export them with
/// `xcrun xcresulttool export attachments --path <result>.xcresult --output-path <dir>`.
@MainActor
final class PaywallScreenshotTests: XCTestCase {
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

  private func services(_ used: [LogType: Int]) async -> (Entitlements, LogGate) {
    let entitlements = Entitlements()
    await entitlements.refresh()
    let gate = LogGate(entitlements: entitlements)
    gate.apply([BabyAllowance(babyId: "b1", unlocked: false, used: used)])
    return (entitlements, gate)
  }

  func testPaywallOnTheSixthNappy() async throws {
    let (entitlements, _) = await services([.nappy: 5])
    try await snapshot("Paywall, sixth nappy", PaywallView(type: .nappy).environment(entitlements), settle: 15)
  }

  func testPaywallForAWidgetLog() async throws {
    let (entitlements, _) = await services([.nappy: 5])
    try await snapshot("Paywall, entry waiting from a widget", PaywallView(type: .nappy, heldCount: 1).environment(entitlements), settle: 15)
  }

  func testLockedPatterns() async throws {
    let (entitlements, gate) = await services([.feed: 5])
    let view = NavigationStack {
      SubscriptionGate(babyId: "b1", feature: .patterns) { Text("Patterns") }
    }
    try await snapshot("Patterns after the free entries", view.environment(entitlements).environment(gate))
  }

  func testSubscriptionRow() async throws {
    let (entitlements, gate) = await services([.feed: 2, .nappy: 5, .bottle: 1])
    try await snapshot("Profile, free entries left", row(entitlements, gate))

    _ = try await session.buyProduct(identifier: Subscription.monthlyProductID)
    await entitlements.refresh()
    try await snapshot("Profile, subscribed", row(entitlements, gate))
  }

  private func row(_ entitlements: Entitlements, _ gate: LogGate) -> some View {
    ScreenScaffold(showsBack: false) {
      ScreenTitle("Profile")
      Card { SubscriptionRow(babyId: "b1") }
    }
    .environment(entitlements)
    .environment(gate)
  }

  /// SubscriptionStoreView loads its products after appearing, so the paywall needs longer.
  private func snapshot(_ name: String, _ view: some View, settle: Int = 4) async throws {
    let window = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
    )
    let previous = window.rootViewController
    defer { window.rootViewController = previous }
    window.rootViewController = UIHostingController(rootView: view)
    try await Task.sleep(for: .seconds(settle))
    let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
      window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
    }
    let attachment = XCTAttachment(image: image)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
