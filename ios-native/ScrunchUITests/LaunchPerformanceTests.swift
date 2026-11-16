import XCTest

/// Cold launch and time-to-usable-home. Run on a simulator or device that is already
/// signed in with at least one baby, otherwise the home tests skip.
final class LaunchPerformanceTests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  /// Process start to first frame, as reported by Xcode's launch metric.
  func testColdLaunch() {
    measure(metrics: [XCTApplicationLaunchMetric()]) {
      XCUIApplication().launch()
    }
  }

  /// `ScrunchApp.init` to the home screen having a baby to show (`LaunchMetrics`).
  func testTimeToUsableHome() throws {
    let app = XCUIApplication()
    app.launch()
    try XCTSkipUnless(app.buttons["Log"].waitForExistence(timeout: 30), "Sign in on this simulator first")
    app.terminate()

    let options = XCTMeasureOptions()
    options.iterationCount = 5
    let metric = XCTOSSignpostMetric(subsystem: "com.nickmcblain.babysteps", category: "launch", name: "TimeToUsableHome")
    measure(metrics: [metric], options: options) {
      app.launch()
      XCTAssertTrue(app.buttons["Log"].waitForExistence(timeout: 30))
      // The interval ends when the babies list is known, a moment after the dock appears.
      Thread.sleep(forTimeInterval: 1)
      app.terminate()
    }
  }
}
