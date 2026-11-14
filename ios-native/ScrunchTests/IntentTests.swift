import ScrunchCore
import XCTest
@testable import Scrunch

@MainActor
final class IntentTests: XCTestCase {
  private var savedBabies: Data?

  override func setUp() {
    savedBabies = GlanceStore.defaults.data(forKey: SharedBabies.storageKey)
  }

  override func tearDown() {
    GlanceStore.defaults.set(savedBabies, forKey: SharedBabies.storageKey)
  }

  func testOptionsMapToCoreKinds() {
    XCTAssertEqual(NappyOption.wet.kind, .wee)
    XCTAssertEqual(NappyOption.dirty.kind, .poo)
    XCTAssertEqual(NappyOption.both.kind, .both)
    XCTAssertEqual(TimerOption.nap.kind, .sleep)
    XCTAssertEqual(TimerOption.feed.kind, .feed)
    for kind in [TimerKind.sleep, .feed, .tummy, .pump] {
      XCTAssertEqual(TimerOption(kind).kind, kind)
    }
    XCTAssertEqual(TimerOption.tummy.spoken, "tummy time")
  }

  func testMissingBabyFallsBackToActiveBaby() throws {
    PendingLogSender.publish(babies: [], activeId: nil)
    XCTAssertThrowsError(try BabyEntity?.none.resolved())

    GlanceStore.defaults.set(
      try JSONEncoder().encode(SharedBabies(babies: [.init(id: "b1", name: "Nico"), .init(id: "b2", name: "Ada")], activeId: "b2")),
      forKey: SharedBabies.storageKey
    )
    XCTAssertEqual(try BabyEntity?.none.resolved().name, "Ada")
    XCTAssertEqual(try BabyEntity?.some(BabyEntity(.init(id: "b1", name: "Nico"))).resolved().id, "b1")
  }

  func testSpokenSummariesStartLowercase() {
    XCTAssertEqual(QuickLog.nappy(.wee).summary.lowercasedFirst, "wet nappy")
  }
}
