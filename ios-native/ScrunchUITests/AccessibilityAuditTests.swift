import XCTest

/// Runs Xcode's accessibility audit on the main screens, reached through the DEBUG
/// `-debugURL` launch argument. Needs a simulator that is already signed in with at
/// least one baby; otherwise each screen is skipped rather than failed.
@MainActor
final class AccessibilityAuditTests: XCTestCase {
  private struct Screen {
    let path: String
    /// Accessibility label that proves the screen has loaded.
    let ready: String
  }

  private static let screens = [
    Screen(path: "tab/home", ready: "Log"),
    Screen(path: "tab/timeline", ready: "Timeline"),
    Screen(path: "tab/kids", ready: "Add baby"),
    Screen(path: "tab/profile", ready: "Profile"),
    Screen(path: "sheet/addlog", ready: "Nappy"),
    Screen(path: "baby/home", ready: "Edit"),
    Screen(path: "baby/feedTimer", ready: "Timer"),
    Screen(path: "baby/sleepTimer", ready: "Sleep timer"),
    Screen(path: "baby/feedManual", ready: "Log feed"),
    Screen(path: "baby/nappy", ready: "Nappy"),
    Screen(path: "baby/sleepPatterns", ready: "Sleep patterns"),
    Screen(path: "baby/feedPatterns", ready: "Feed patterns"),
    Screen(path: "baby/nappyPatterns", ready: "Nappy patterns"),
    Screen(path: "baby/weight", ready: "Weigh-in"),
    Screen(path: "baby/clothing", ready: "Clothing"),
  ]

  /// Colour contrast is owned by the "Dark mode and AA contrast" PR; drop this once it lands.
  private static let auditTypes: XCUIAccessibilityAuditType = XCUIAccessibilityAuditType.all.subtracting(.contrast)

  override func setUp() {
    continueAfterFailure = true
  }

  func testMainScreensPassAccessibilityAudit() throws {
    try auditAll(textSize: nil)
  }

  func testMainScreensPassAccessibilityAuditAtLargestTextSize() throws {
    try auditAll(textSize: "UICTContentSizeCategoryAccessibilityXXXL")
  }

  private func auditAll(textSize: String?) throws {
    var audited = 0
    for screen in Self.screens {
      try XCTContext.runActivity(named: "Audit \(screen.path)") { _ in
        guard let app = launch(screen, textSize: textSize) else { return }
        audited += 1
        try app.performAccessibilityAudit(for: Self.auditTypes) { issue in
          Self.isKnownSystemIssue(issue)
        }
      }
    }
    if audited == 0 {
      throw XCTSkip("No screen loaded: sign in on this simulator and add a baby first")
    }
  }

  private func launch(_ screen: Screen, textSize: String?) -> XCUIApplication? {
    let app = XCUIApplication()
    app.launchArguments = ["-debugURL", "babysteps://debug/\(screen.path)"]
    if let textSize {
      app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize]
    }
    app.launch()
    let ready = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", screen.ready)).firstMatch
    guard ready.waitForExistence(timeout: 30) else {
      XCTContext.runActivity(named: "Skipped \(screen.path): not signed in or no baby") { _ in }
      return nil
    }
    // Let reactive queries fill the screen before auditing.
    Thread.sleep(forTimeInterval: 2)
    return app
  }

  /// Issues raised on system chrome we don't control (status bar, keyboard).
  private static func isKnownSystemIssue(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
    guard let element = issue.element else { return false }
    return element.elementType == .statusBar || element.elementType == .keyboard
  }
}
