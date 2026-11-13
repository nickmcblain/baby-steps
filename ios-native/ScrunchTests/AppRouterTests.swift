import ScrunchCore
import XCTest
@testable import Scrunch

@MainActor
final class AppRouterTests: XCTestCase {
  func testLiveActivityDeepLinkOpensTheTimer() {
    let router = AppRouter()
    router.handle(url: URL(string: "babysteps://baby/abc123/sleep/timer")!)
    XCTAssertEqual(router.path, [.baby("abc123", .sleepTimer)])

    router.handle(url: URL(string: "babysteps://baby/abc123/pump/timer")!)
    XCTAssertEqual(router.path, [.baby("abc123", .pumpTimer)])
  }

  func testUnknownKindFallsBackToBabyHome() {
    let router = AppRouter()
    router.handle(url: URL(string: "babysteps://baby/abc123/bath/timer")!)
    XCTAssertEqual(router.path, [.baby("abc123", .home)])
  }

  func testOtherSchemesAreIgnored() {
    let router = AppRouter()
    router.handle(url: URL(string: "https://example.com/baby/abc123/sleep/timer")!)
    XCTAssertTrue(router.path.isEmpty)
  }

  func testDeepLinkMatchesTimerSession() {
    let session = TimerSession(kind: .tummy, babyId: "b1", babyName: nil, now: 0)
    let router = AppRouter()
    router.handle(url: URL(string: session.deepLink)!)
    XCTAssertEqual(router.path, [.baby("b1", .tummyTimer)])
  }

  func testDismissToBabyHomePopsOrReplaces() {
    let router = AppRouter()
    router.path = [.baby("b1", .home), .baby("b1", .feedTimer), .baby("b1", .feedManual(nil))]
    router.dismissToBabyHome("b1")
    XCTAssertEqual(router.path, [.baby("b1", .home)])

    router.path = [.baby("b1", .sleepManual(nil))]
    router.dismissToBabyHome("b1")
    XCTAssertEqual(router.path, [.baby("b1", .home)])
  }
}
