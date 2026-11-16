import XCTest

/// Airplane Mode on a simulator: Convex is pointed at a host that can't be reached, a nappy
/// is logged, the app is killed, and the next normal launch sends it. Needs a signed-in
/// simulator with a baby, and writes one wet nappy to that account's (dev) data.
final class OfflineLogTests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  func testNappyLoggedOfflineSurvivesAKillAndSyncs() throws {
    let app = XCUIApplication()
    app.launch()
    try XCTSkipUnless(app.buttons["Log"].waitForExistence(timeout: 30), "Sign in on this simulator first")
    // Let the live babies list reach the last-known cache.
    XCTAssertTrue(app.buttons["Log wet nappy"].waitForExistence(timeout: 30))
    sleep(3)
    app.terminate()

    app.launchEnvironment["SCRUNCH_CONVEX_URL"] = "https://offline.invalid"
    app.launch()
    // The home renders from the last-known copy with no connection.
    let wet = app.buttons["Log wet nappy"]
    XCTAssertTrue(wet.waitForExistence(timeout: 10), "home should render from cache offline")
    wet.tap()
    let saved = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Saved on this phone")).firstMatch
    XCTAssertTrue(saved.waitForExistence(timeout: 15), "an offline log should be kept on the phone")
    let queuedBanner = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "saved, will sync")).firstMatch
    XCTAssertTrue(queuedBanner.waitForExistence(timeout: 10), "the banner should count the queued log")
    app.terminate()

    app.launchEnvironment.removeValue(forKey: "SCRUNCH_CONVEX_URL")
    app.launch()
    XCTAssertTrue(app.buttons["Log"].waitForExistence(timeout: 30))
    // Once Convex answers, the queue empties and the banner goes away.
    let gone = NSPredicate(format: "exists == false")
    expectation(for: gone, evaluatedWith: app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "saved, will sync")).firstMatch)
    waitForExpectations(timeout: 30)
    sleep(2)
    app.terminate()
  }
}
