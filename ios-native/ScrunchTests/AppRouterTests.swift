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

  func testUnknownKindFallsBackToTheHomeTab() {
    let router = AppRouter()
    router.tab = .kids
    router.path = [.baby("abc123", .edit)]
    router.handle(url: URL(string: "babysteps://baby/abc123/bath/timer")!)
    XCTAssertTrue(router.path.isEmpty)
    XCTAssertEqual(router.tab, .home)
    XCTAssertEqual(router.requestedBabyId, "abc123")
  }

  func testTimerDeepLinkSelectsThatBaby() {
    let router = AppRouter()
    router.handle(url: URL(string: "babysteps://baby/b2/feed/timer")!)
    XCTAssertEqual(router.requestedBabyId, "b2")
    XCTAssertEqual(router.path, [.baby("b2", .feedTimer)])
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

  func testShowHomeReturnsToTheHomeTab() {
    let router = AppRouter()
    router.tab = .timeline
    router.path = [.baby("b1", .feedTimer), .baby("b1", .feedManual(nil, .breast))]
    router.showHome("b1")
    XCTAssertTrue(router.path.isEmpty)
    XCTAssertEqual(router.tab, .home)
    XCTAssertEqual(router.requestedBabyId, "b1")
  }

  func testShowTimelineOpensTheTimelineTabForThatBaby() {
    let router = AppRouter()
    router.path = [.baby("b1", .feedPatterns)]
    router.showTimeline("b2")
    XCTAssertTrue(router.path.isEmpty)
    XCTAssertEqual(router.tab, .timeline)
    XCTAssertEqual(router.requestedBabyId, "b2")
  }
}
