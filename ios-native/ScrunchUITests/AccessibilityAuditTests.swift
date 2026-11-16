import XCTest

/// Runs Xcode's accessibility audit on the main screens, reached through the DEBUG
/// `-debugURL` launch argument. Needs a simulator that is already signed in with at
/// least one baby; otherwise the whole test is skipped rather than failed.
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
    Screen(path: "tab/kids", ready: "Add a baby"),
    Screen(path: "tab/profile", ready: "Profile"),
    Screen(path: "sheet/addlog", ready: "Nappy"),
    Screen(path: "baby/edit", ready: "Edit baby"),
    Screen(path: "baby/feedTimer", ready: "Feed timer"),
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
    for (index, screen) in Self.screens.enumerated() {
      try XCTContext.runActivity(named: "Audit \(screen.path)") { _ in
        guard let app = launch(screen, textSize: textSize) else {
          if index == 0 {
            throw XCTSkip("Home did not load: sign in on this simulator and add a baby first")
          }
          XCTFail("\(screen.path) never showed \"\(screen.ready)\"")
          return
        }
        try app.performAccessibilityAudit(for: Self.auditTypes) { issue in
          if Self.isKnownSystemIssue(issue) || Self.isTextBehindSheet(issue, on: screen) || Self.isTextCutByScreenEdge(issue, in: app) {
            return true
          }
          // The audit's own message doesn't say which element; this makes failures actionable.
          let element = issue.element.map { "\($0.elementType.rawValue) \"\($0.label)\" at \($0.frame)" } ?? "no element"
          print("Audit issue on \(screen.path): \(issue.compactDescription), \(element)")
          return false
        }
      }
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
    guard ready.waitForExistence(timeout: 30) else { return nil }
    // Let reactive queries fill the screen before auditing.
    Thread.sleep(forTimeInterval: 2)
    return app
  }

  /// A part-height sheet leaves the dimmed screen behind it visible. The audit reads that text
  /// from the screenshot, but VoiceOver rightly skips it while the sheet is modal.
  private static func isTextBehindSheet(_ issue: XCUIAccessibilityAuditIssue, on screen: Screen) -> Bool {
    screen.path.hasPrefix("sheet/") && issue.auditType == .elementDetection && issue.element == nil
  }

  /// A list row that runs off the bottom of the screen is one combined element whose frame
  /// leaves the window, so the audit can't match the visible half of its text to it and reports
  /// that text with no element. Only skipped when such a row is actually on screen.
  private static func isTextCutByScreenEdge(_ issue: XCUIAccessibilityAuditIssue, in app: XCUIApplication) -> Bool {
    guard issue.auditType == .elementDetection, issue.element == nil else { return false }
    let bottom = app.windows.firstMatch.frame.maxY
    return app.staticTexts.allElementsBoundByIndex.contains { text in
      text.frame.height > 40 && text.frame.minY < bottom && text.frame.maxY > bottom
    }
  }

  /// Issues raised on system chrome we don't control (status bar, keyboard).
  private static func isKnownSystemIssue(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
    guard let element = issue.element else { return false }
    return element.elementType == .statusBar || element.elementType == .keyboard
  }
}
