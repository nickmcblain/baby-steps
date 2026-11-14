import ScrunchCore
import StoreKitTest
import SwiftUI
import XCTest
@testable import Scrunch

/// Renders the Plus screens against StoreKit/Scrunch.storekit and attaches PNGs to the test
/// result, for App Review and PR screenshots. Export them with
/// `xcrun xcresulttool export attachments --path <result>.xcresult --output-path <dir>`.
@MainActor
final class PlusScreenshotTests: XCTestCase {
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

  func testPaywall() async throws {
    let entitlements = Entitlements()
    await entitlements.refresh()
    try await snapshot("Paywall", PlusPaywallView(feature: .patterns).environment(entitlements))
  }

  func testLockedPatterns() async throws {
    let entitlements = Entitlements()
    await entitlements.refresh()
    let gate = NavigationStack {
      PlusGate(feature: .patterns) { Text("Patterns") }
    }
    try await snapshot("Locked patterns", gate.environment(entitlements))
  }

  func testSubscriptionRow() async throws {
    let entitlements = Entitlements()
    await entitlements.refresh()
    try await snapshot("Subscription row, not subscribed", row(entitlements))

    _ = try await session.buyProduct(identifier: Plus.monthlyProductID)
    await entitlements.refresh()
    try await snapshot("Subscription row, in trial", row(entitlements))
  }

  private func row(_ entitlements: Entitlements) -> some View {
    ScreenScaffold(showsBack: false) {
      ScreenTitle("Profile")
      Card { PlusSubscriptionRow() }
    }
    .environment(entitlements)
  }

  private func snapshot(_ name: String, _ view: some View) async throws {
    let window = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
    )
    let previous = window.rootViewController
    defer { window.rootViewController = previous }
    window.rootViewController = UIHostingController(rootView: view)
    try await Task.sleep(for: .seconds(4))
    let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
      window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
    }
    let attachment = XCTAttachment(image: image)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
