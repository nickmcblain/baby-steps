import Foundation
import XCTest
@testable import ScrunchCore

/// Stands in for Convex: dedupes on (babyId, clientId) like `insertOnce` in convex/lib/logEvents.ts.
@MainActor
private final class FakeServer {
  private(set) var events: [(clientId: String, name: String, babyId: String)] = []
  private(set) var calls: [String] = []

  func receive(_ entry: PendingMutation) {
    guard case .string(let clientId) = entry.args["clientId"],
          case .string(let babyId) = entry.args["babyId"] else { return XCTFail("missing clientId or babyId") }
    calls.append(clientId)
    if !events.contains(where: { $0.clientId == clientId && $0.babyId == babyId }) {
      events.append((clientId, entry.name, babyId))
    }
  }
}

private struct Dropped: Error {}

@MainActor
final class OfflineSyncTests: XCTestCase {
  private var dir: URL!

  override func setUp() async throws {
    dir = FileManager.default.temporaryDirectory.appendingPathComponent("scrunch-tests-\(UUID().uuidString)")
  }

  override func tearDown() async throws {
    try? FileManager.default.removeItem(at: dir)
  }

  private var queueFile: URL { dir.appendingPathComponent("outbox.json") }

  private func nappy(_ baby: String = "baby1", at loggedAt: Double = 1_000) -> [String: ConvexValue] {
    API.events.logNappy(babyId: baby, loggedAt: loggedAt, nappy: .wee, weeSize: .small).args
  }

  // MARK: Offline then reconnect

  func testOfflineLogIsKeptAcrossRelaunchAndSyncsOnce() async throws {
    let server = FakeServer()
    var online = false
    let first = Outbox(fileURL: queueFile) { server.receive($0) }
    first.canSend = { online }

    let outcome = try await first.submit("events:logNappy", nappy(), now: 1, id: "a")
    XCTAssertEqual(outcome, .queued)
    XCTAssertEqual(first.pending.map(\.id), ["a"])
    XCTAssertTrue(server.events.isEmpty)

    // App killed while offline, then relaunched with signal.
    let relaunched = Outbox(fileURL: queueFile) { server.receive($0) }
    XCTAssertEqual(relaunched.pending.map(\.id), ["a"])
    online = true
    relaunched.canSend = { online }
    await relaunched.flush()

    XCTAssertTrue(relaunched.pending.isEmpty)
    XCTAssertEqual(server.events.map(\.clientId), ["a"])
    XCTAssertEqual(Outbox(fileURL: queueFile) { _ in }.pending, [], "queue file is emptied once synced")
  }

  func testFlushSendsInTheOrderEntriesWereLogged() async throws {
    let server = FakeServer()
    var online = false
    let outbox = Outbox(fileURL: queueFile) { server.receive($0) }
    outbox.canSend = { online }
    for id in ["1", "2", "3", "4"] {
      try await outbox.submit("events:logNappy", nappy(), now: Double(id)!, id: id)
    }
    online = true
    await outbox.flush()
    XCTAssertEqual(server.calls, ["1", "2", "3", "4"])
  }

  func testEveryEntryCarriesItsIdAsClientId() async throws {
    var sent: [PendingMutation] = []
    let outbox = Outbox(fileURL: nil) { sent.append($0) }
    try await outbox.submit("events:logSleep", API.events.logSleep(babyId: "b", loggedAt: 5, durationMinutes: 30).args, now: 9, id: "k1")
    XCTAssertEqual(sent.first?.args["clientId"], .string("k1"))
    XCTAssertEqual(sent.first?.args["durationMinutes"], .number(30))
  }

  // MARK: Dedupe

  func testReplayAfterALostReplyDoesNotDuplicate() async throws {
    let server = FakeServer()
    var dropReply = true
    let outbox = Outbox(fileURL: queueFile) { entry in
      server.receive(entry)
      if dropReply { throw Dropped() }
    }
    let outcome = try await outbox.submit("events:logFeed", nappy(), now: 1, id: "x")
    XCTAssertEqual(outcome, .queued, "no reply, so it stays queued")
    XCTAssertEqual(outbox.pending.first?.attempts, 1)

    dropReply = false
    await outbox.flush()
    XCTAssertTrue(outbox.pending.isEmpty)
    XCTAssertEqual(server.calls, ["x", "x"])
    XCTAssertEqual(server.events.count, 1)
  }

  func testRepeatedFlushesDoNotDoubleSend() async throws {
    let server = FakeServer()
    let outbox = Outbox(fileURL: nil) { entry in
      try await Task.sleep(for: .milliseconds(30))
      server.receive(entry)
    }
    outbox.canSend = { false }
    try await outbox.submit("events:logNappy", nappy(), now: 1, id: "only")
    outbox.canSend = { true }
    async let a: Void = outbox.flush()
    async let b: Void = outbox.flush()
    async let c: Void = outbox.flush()
    _ = await (a, b, c)
    XCTAssertEqual(server.calls, ["only"])
  }

  // MARK: Timeouts and errors

  func testSlowConvexReturnsQueuedThenSyncsInTheBackground() async throws {
    let server = FakeServer()
    let outbox = Outbox(fileURL: nil) { entry in
      try await Task.sleep(for: .milliseconds(300))
      server.receive(entry)
    }
    let outcome = try await outbox.submit("events:logNappy", nappy(), now: 1, id: "slow", timeout: .milliseconds(20))
    XCTAssertEqual(outcome, .queued)
    XCTAssertEqual(outbox.pending.count, 1)
    try await Task.sleep(for: .milliseconds(600))
    XCTAssertTrue(outbox.pending.isEmpty)
    XCTAssertEqual(server.events.count, 1)
  }

  func testFastConvexReturnsSynced() async throws {
    let outbox = Outbox(fileURL: nil) { _ in }
    let outcome = try await outbox.submit("events:logNappy", nappy(), now: 1)
    XCTAssertEqual(outcome, .synced)
    XCTAssertTrue(outbox.pending.isEmpty)
  }

  func testRejectionWhileTheFormIsOpenThrowsAndIsNotKept() async throws {
    let outbox = Outbox(fileURL: queueFile) { _ in throw Outbox.Rejected(message: "Wee size is required") }
    do {
      try await outbox.submit("events:logNappy", nappy(), now: 1)
      XCTFail("expected a rejection")
    } catch let error as Outbox.Rejected {
      XCTAssertEqual(error.localizedDescription, "Wee size is required")
    }
    XCTAssertTrue(outbox.pending.isEmpty)
    XCTAssertTrue(outbox.failures.isEmpty, "the form already showed it")
  }

  func testRejectionAfterReconnectIsReportedNotSilentlyDropped() async throws {
    var online = false
    let outbox = Outbox(fileURL: nil) { entry in
      if entry.id == "bad" { throw Outbox.Rejected(message: "Time can't be in the future") }
    }
    outbox.canSend = { online }
    try await outbox.submit("events:logNappy", nappy(), now: 1, id: "bad")
    try await outbox.submit("events:logNappy", nappy(), now: 2, id: "good")
    online = true
    await outbox.flush()
    XCTAssertTrue(outbox.pending.isEmpty)
    XCTAssertEqual(outbox.failures.map(\.message), ["Time can't be in the future"])
    outbox.dismissFailures()
    XCTAssertTrue(outbox.failures.isEmpty)
  }

  func testAFailingEntryDoesNotBlockTheOnesBehindIt() async throws {
    let server = FakeServer()
    var online = false
    let outbox = Outbox(fileURL: nil) { entry in
      if entry.id == "stuck" { throw Dropped() }
      server.receive(entry)
    }
    outbox.canSend = { online }
    for id in ["stuck", "next", "last"] {
      try await outbox.submit("events:logNappy", nappy(), now: 1, id: id)
    }
    online = true
    await outbox.flush()
    XCTAssertEqual(server.calls, ["next", "last"])
    XCTAssertEqual(outbox.pending.map(\.id), ["stuck"], "kept for the next flush, not lost")
  }

  func testOnChangeFiresForQueueUpdates() async throws {
    var counts: [Int] = []
    let outbox = Outbox(fileURL: nil) { _ in }
    outbox.onChange = { counts.append(outbox.pending.count) }
    try await outbox.submit("events:logNappy", nappy(), now: 1)
    XCTAssertEqual(counts.first, 1)
    XCTAssertEqual(counts.last, 0)
  }

  // MARK: Two devices

  func testTwoPhonesLoggingOfflineAtOnceBothLand() async throws {
    let server = FakeServer()
    var online = false
    let mum = Outbox(fileURL: dir.appendingPathComponent("mum.json")) { server.receive($0) }
    let dad = Outbox(fileURL: dir.appendingPathComponent("dad.json")) { server.receive($0) }
    mum.canSend = { online }
    dad.canSend = { online }

    try await mum.submit("events:logFeed", nappy(at: 100), now: 100)
    try await dad.submit("events:logNappy", nappy(at: 100), now: 100)
    try await mum.submit("events:logSleep", nappy(at: 160), now: 160)
    try await dad.submit("events:logNappy", nappy(at: 170), now: 170)

    online = true
    async let a: Void = mum.flush()
    async let b: Void = dad.flush()
    _ = await (a, b)

    XCTAssertEqual(server.events.count, 4)
    XCTAssertEqual(Set(server.events.map(\.clientId)).count, 4, "fresh UUID per log, so phones never collide")
    XCTAssertTrue(mum.pending.isEmpty)
    XCTAssertTrue(dad.pending.isEmpty)
  }

  // MARK: Last-known cache

  func testConvexValueRoundTripsThroughJSON() throws {
    let value = ConvexValue.object([
      "name": .string("Ada"),
      "asleep": .bool(true),
      "weightGrams": .number(3400),
      "heightCm": .number(52.5),
      "notes": .null,
      "tags": .array([.string("a"), .number(1)]),
    ])
    let data = try JSONEncoder().encode(value)
    XCTAssertEqual(try JSONDecoder().decode(ConvexValue.self, from: data), value)
  }

  func testCachedQueryDecodesIntoTheModel() throws {
    let cache = LastKnownCache(directory: dir)
    let raw = try JSONDecoder().decode(ConvexValue.self, from: Data(#"{"_id":"b1","_creationTime":1,"name":"Ada","dateOfBirth":1700000000000,"weightGrams":3400,"inviteCode":"ABC123","createdBy":"u1"}"#.utf8))
    XCTAssertFalse(cache.contains("babies:list"))
    cache.write("babies:list", .array([raw]))
    XCTAssertTrue(cache.contains("babies:list"))

    let babies: [Baby] = try XCTUnwrap(cache.read("babies:list")).decode()
    XCTAssertEqual(babies.first?.name, "Ada")
    XCTAssertEqual(babies.first?.weightGrams, 3400)

    cache.clear()
    XCTAssertNil(cache.read("babies:list"))
  }

  func testCacheFileNameIsStableForAKey() {
    let a = LastKnownCache(directory: dir).fileURL(for: API.babies.list().key)
    let b = LastKnownCache(directory: dir).fileURL(for: API.babies.list().key)
    XCTAssertEqual(a, b)
    XCTAssertNotEqual(a, LastKnownCache(directory: dir).fileURL(for: "events:dashboard"))
  }

  // MARK: Banner copy

  func testSyncBannerCopy() {
    XCTAssertNil(SyncStatus.message(reachable: true, pending: 0, failure: nil))
    XCTAssertEqual(SyncStatus.message(reachable: true, pending: 1, failure: nil)?.text, "1 log saved, will sync.")
    XCTAssertEqual(SyncStatus.message(reachable: false, pending: 3, failure: nil), .init(text: "Offline. 3 logs saved, will sync.", action: .retry))
    XCTAssertEqual(SyncStatus.message(reachable: false, pending: 0, failure: nil)?.text, "Offline. Showing what's saved on this phone.")
    XCTAssertEqual(SyncStatus.message(reachable: true, pending: 2, failure: "No access")?.action, .dismiss)
  }

  // MARK: Timers across kill / restart

  func testRunningTimerKeepsCountingAcrossRelaunch() throws {
    let start: EpochMs = 1_700_000_000_000
    var sleep = TimerSession(kind: .sleep, babyId: "b", babyName: "Ada", now: start)
    sleep.toggle(now: start)
    var feed = TimerSession(kind: .feed, babyId: "b", babyName: "Ada", now: start)
    feed.tapSide(.left, now: start)
    feed.tapSide(.right, now: start + 4 * 60_000)

    // Persisted, process killed, phone restarted 2 hours later.
    let later = start + 2 * 3_600_000
    let sleepBack = try JSONDecoder().decode(TimerSession.self, from: JSONEncoder().encode(sleep))
    let feedBack = try JSONDecoder().decode(TimerSession.self, from: JSONEncoder().encode(feed))

    XCTAssertEqual(sleepBack.elapsed(now: later), 2 * 3_600_000)
    XCTAssertTrue(sleepBack.isRunning)
    XCTAssertEqual(feedBack.sideElapsed(.left, now: later), 4 * 60_000)
    XCTAssertEqual(feedBack.sideElapsed(.right, now: later), 2 * 3_600_000 - 4 * 60_000)
  }

  func testPausedTimerDoesNotDriftWhileTheAppIsDead() throws {
    let start: EpochMs = 1_700_000_000_000
    var tummy = TimerSession(kind: .tummy, babyId: "b", babyName: nil, now: start)
    tummy.toggle(now: start)
    tummy.toggle(now: start + 5 * 60_000)
    let back = try JSONDecoder().decode(TimerSession.self, from: JSONEncoder().encode(tummy))
    XCTAssertEqual(back.elapsed(now: start + 86_400_000), 5 * 60_000)
    XCTAssertFalse(back.isRunning)
  }
}
