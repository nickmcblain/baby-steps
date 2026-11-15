import ScrunchCore
import StoreKitTest
import XCTest
@testable import Scrunch

/// The free allowance at every entry point: forms and quick log (LogGate), voice (LogGate with
/// no type), and Siri, Shortcuts, widgets and the Live Activity (QuickLogStore).
@MainActor
final class FreeAllowanceAppTests: XCTestCase {
  private var session: SKTestSession!
  private var saved: [String: Any] = [:]
  private let sharedKeys = [SharedAllowance.storageKey, PendingLogQueue.storageKey, PendingLogQueue.heldKey, SharedBabies.storageKey, openPaywallKey]

  override func setUp() async throws {
    session = try SKTestSession(configurationFileNamed: "Scrunch")
    session.resetToDefaultState()
    session.disableDialogs = true
    session.clearTransactions()
    for key in sharedKeys {
      saved[key] = GlanceStore.defaults.object(forKey: key)
      GlanceStore.defaults.removeObject(forKey: key)
    }
    UserDefaults.standard.removeObject(forKey: "allowance.hinted")
  }

  override func tearDown() async throws {
    session.clearTransactions()
    session = nil
    for key in sharedKeys { GlanceStore.defaults.set(saved[key], forKey: key) }
  }

  private func gate(_ used: [LogType: Int], unlocked: Bool = false) async -> LogGate {
    let entitlements = Entitlements()
    await entitlements.refresh()
    let gate = LogGate(entitlements: entitlements)
    gate.apply([BabyAllowance(babyId: "b1", unlocked: unlocked, used: used)])
    return gate
  }

  private func waitForPaywall(_ gate: LogGate) async throws -> LogGate.Paywall {
    for _ in 0..<100 {
      if let paywall = gate.paywall { return paywall }
      try await Task.sleep(for: .milliseconds(20))
    }
    return try XCTUnwrap(gate.paywall)
  }

  // MARK: Forms, quick log and voice

  func testSavesWhileFreeEntriesRemain() async throws {
    let gate = await gate([.nappy: 4])
    let id = try await gate.save(.nappy, babyId: "b1") { "e1" }
    XCTAssertEqual(id, "e1")
    XCTAssertNil(gate.paywall)
  }

  func testSixthEntryShowsThePaywallAndClosingSavesNothing() async throws {
    let gate = await gate([.nappy: 5])
    let saves = Counter()
    let pending = Task { try await gate.save(.nappy, babyId: "b1") { saves.count += 1; return "e1" } }
    let paywall = try await waitForPaywall(gate)
    XCTAssertEqual(paywall.type, .nappy)
    gate.paywallClosed()
    let result = try await pending.value
    XCTAssertNil(result)
    XCTAssertEqual(saves.count, 0)
  }

  func testSubscribingFromThePaywallSavesWhatWasTyped() async throws {
    let gate = await gate([.bottle: 5])
    let saves = Counter()
    let pending = Task { try await gate.save(.bottle, babyId: "b1") { saves.count += 1; return "e1" } }
    _ = try await waitForPaywall(gate)
    _ = try await session.buyProduct(identifier: Subscription.monthlyProductID)
    for _ in 0..<50 where !gate.entitlements.subscribed {
      await gate.entitlements.refresh()
      try await Task.sleep(for: .milliseconds(100))
    }
    XCTAssertTrue(gate.entitlements.subscribed)
    gate.paywallClosed()
    let result = try await pending.value
    XCTAssertEqual(result, "e1")
    XCTAssertEqual(saves.count, 1)
  }

  func testSleepAndVoiceNeverHitThePaywallUpFront() async throws {
    let gate = await gate([.feed: 5, .nappy: 5, .bottle: 5])
    let sleep = try await gate.save(FreeAllowance.type(for: .sleep(minutes: 40)), babyId: "b1") { "sleep" }
    XCTAssertEqual(sleep, "sleep")
    let voice = try await gate.save(nil, babyId: "b1") { "voice" }
    XCTAssertEqual(voice, "voice")
    let otherType = try await gate.save(.pump, babyId: "b1") { "pump" }
    XCTAssertEqual(otherType, "pump")
  }

  func testAPartnersSubscriptionUnlocksTheBaby() async throws {
    let gate = await gate([.nappy: 9], unlocked: true)
    let id = try await gate.save(.nappy, babyId: "b1") { "e1" }
    XCTAssertEqual(id, "e1")
  }

  func testAskAndPatternsLockOnlyOnceAFreeAllowanceRunsOut() async throws {
    let early = await gate([.feed: 4])
    let used = await gate([.feed: 5])
    let shared = await gate([.feed: 5], unlocked: true)
    XCTAssertTrue(early.featureOpen("b1"))
    XCTAssertFalse(used.featureOpen("b1"))
    XCTAssertTrue(shared.featureOpen("b1"))
  }

  func testHintShowsOncePerType() async throws {
    let gate = await gate([.feed: 1])
    let undo = UndoCenter()
    gate.undo = undo
    gate.apply([BabyAllowance(babyId: "b1", unlocked: false, used: [.feed: 2])])
    try await Task.sleep(for: .milliseconds(100))
    XCTAssertEqual(undo.toast?.message, "3 of 5 free feeds left. Sleep is always free.")
    undo.settle()
    gate.apply([BabyAllowance(babyId: "b1", unlocked: false, used: [.feed: 3])])
    try await Task.sleep(for: .milliseconds(100))
    XCTAssertNil(undo.toast)
  }

  func testAllowanceIsMirroredForWidgetsAndSiri() async throws {
    _ = await gate([.nappy: 5])
    let shared = SharedAllowance.load(from: GlanceStore.defaults)
    XCTAssertFalse(shared.canLog(.nappy(.wet), babyId: "b1"))
    XCTAssertTrue(shared.canLog(.sleep(minutes: 30), babyId: "b1"))
  }

  // MARK: Siri, Shortcuts, widgets, the Live Activity and "Log from a description"

  func testQueuedLogsPastTheAllowanceAreHeldNotDropped() async throws {
    _ = await gate([.nappy: 5])
    let outcome = await QuickLogStore.record(PendingLog(babyId: "b1", loggedAt: 0, log: .nappy(.wet)))
    XCTAssertEqual(outcome, .held(.nappy))
    XCTAssertEqual(QuickLogStore.held.all.map(\.log), [.nappy(.wet)])
    XCTAssertFalse(QuickLogStore.queue.all.contains { $0.log == .nappy(.wet) })
  }

  func testSleepFromSiriOrTheLiveActivityIsAlwaysQueued() async throws {
    _ = await gate([.nappy: 5, .feed: 5])
    let outcome = await QuickLogStore.record(PendingLog(babyId: "b1", loggedAt: 0, log: .sleep(minutes: 25)))
    XCTAssertEqual(outcome, .queued)
    XCTAssertTrue(QuickLogStore.held.all.isEmpty)
  }

  func testTheFifthWidgetTapCountsSoTheSixthIsHeld() async throws {
    _ = await gate([.nappy: 4])
    let fifth = await QuickLogStore.record(PendingLog(babyId: "b1", loggedAt: 0, log: .nappy(.dirty)))
    let sixth = await QuickLogStore.record(PendingLog(babyId: "b1", loggedAt: 0, log: .nappy(.dirty)))
    XCTAssertEqual(fifth, .queued)
    XCTAssertEqual(sixth, .held(.nappy))
  }

  func testSiriLogIntentPastTheAllowanceHoldsTheLogAndAsksToOpenScrunch() async throws {
    _ = await gate([.nappy: 5])
    GlanceStore.defaults.set(
      try JSONEncoder().encode(SharedBabies(babies: [.init(id: "b1", name: "Nico")], activeId: "b1")),
      forKey: SharedBabies.storageKey
    )
    do {
      _ = try await LogNappyIntent(nappy: .wet).perform()
      XCTFail("Should not report the nappy as logged")
    } catch {}
    XCTAssertEqual(QuickLogStore.held.all.count, 1)
  }

  func testHeldLogsBringUpThePaywallOnceWhenScrunchOpens() async throws {
    let gate = await gate([.nappy: 5])
    QuickLogStore.held.enqueue(PendingLog(babyId: "b1", loggedAt: 0, log: .nappy(.wet)))
    gate.presentHeldIfNeeded()
    XCTAssertEqual(gate.paywall?.heldCount, 1)
    gate.paywallClosed()
    gate.presentHeldIfNeeded()
    XCTAssertNil(gate.paywall, "Not shown again for the same log")
    XCTAssertEqual(gate.held.count, 1, "Still kept after closing")
    gate.discardHeld()
    XCTAssertTrue(gate.held.isEmpty)
  }

  func testLockedWidgetButtonOpensThePaywall() async throws {
    let gate = await gate([.nappy: 5])
    _ = try await OpenPaywallIntent().perform()
    gate.presentHeldIfNeeded()
    XCTAssertNotNil(gate.paywall)
  }
}

@MainActor
private final class Counter {
  var count = 0
}
