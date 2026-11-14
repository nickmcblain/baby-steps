import Foundation

// Offline tolerance: a persisted queue of event logs that replays until Convex confirms
// each one, plus a last-known copy of query results so screens can render before the
// network answers.

extension ConvexValue: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([ConvexValue].self) {
      self = .array(value)
    } else {
      self = .object(try container.decode([String: ConvexValue].self))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null: try container.encodeNil()
    case .bool(let value): try container.encode(value)
    case .number(let value): try container.encode(value)
    case .string(let value): try container.encode(value)
    case .array(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    }
  }

  /// Decodes a model from a raw query result, the same way ConvexMobile would.
  public func decode<T: Decodable>(as type: T.Type = T.self) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(jsonString().utf8))
  }
}

/// One queued mutation. `id` doubles as the `clientId` idempotency key sent to Convex.
public struct PendingMutation: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let args: [String: ConvexValue]
  public let queuedAt: EpochMs
  public var attempts: Int

  public init(id: String, name: String, args: [String: ConvexValue], queuedAt: EpochMs, attempts: Int = 0) {
    self.id = id
    self.name = name
    self.args = args
    self.queuedAt = queuedAt
    self.attempts = attempts
  }
}

/// Persisted, ordered queue of event logs.
///
/// ConvexMobile keeps unsent mutations in memory and waits, without a timeout, for the
/// socket to come back, so an offline save never returns and is gone if the app is
/// killed. Every log is written here first, sent in order, and removed only once Convex
/// answers. Retries reuse the same `clientId`, so a log that reached the server before
/// the app died can't land twice.
@MainActor
public final class Outbox {
  public enum Outcome: Equatable, Sendable {
    /// Convex confirmed the write.
    case synced
    /// Kept on this phone; it will be sent when Convex is reachable.
    case queued
  }

  /// Convex refused the write (a `ConvexError`), so retrying can't help.
  public struct Rejected: LocalizedError, Equatable, Sendable {
    public let message: String
    public init(message: String) { self.message = message }
    public var errorDescription: String? { message }
  }

  /// A queued write Convex refused after the form had already closed.
  public struct Failure: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let message: String
  }

  public typealias Send = @MainActor (PendingMutation) async throws -> Void

  public private(set) var pending: [PendingMutation]
  public private(set) var failures: [Failure] = []
  /// Called after every change to `pending` or `failures`.
  public var onChange: (@MainActor () -> Void)?
  /// False while Convex auth isn't ready; sending unauthenticated would be rejected.
  public var canSend: @MainActor () -> Bool = { true }

  private let fileURL: URL?
  private let send: Send
  private var waiters: [String: CheckedContinuation<Resolution, Never>] = [:]
  private var flushing = false

  private enum Resolution {
    case synced, queued, rejected(String)
  }

  public init(fileURL: URL?, send: @escaping Send) {
    self.fileURL = fileURL
    self.send = send
    pending = fileURL.flatMap { try? Data(contentsOf: $0) }
      .flatMap { try? JSONDecoder().decode([PendingMutation].self, from: $0) } ?? []
  }

  /// Queues `name(args)` with a fresh `clientId` and tries to send it. Returns `.synced`
  /// if Convex answers within `timeout`, `.queued` if not, and throws `Rejected` when
  /// Convex refuses it.
  @discardableResult
  public func submit(
    _ name: String,
    _ args: [String: ConvexValue],
    now: EpochMs,
    id: String = UUID().uuidString.lowercased(),
    timeout: Duration = .seconds(4)
  ) async throws -> Outcome {
    var keyed = args
    keyed["clientId"] = .string(id)
    pending.append(PendingMutation(id: id, name: name, args: keyed, queuedAt: now))
    changed()
    guard canSend() else { return .queued }

    let resolution = await withCheckedContinuation { (continuation: CheckedContinuation<Resolution, Never>) in
      waiters[id] = continuation
      Task { [weak self] in
        try? await Task.sleep(for: timeout)
        self?.resolve(id, .queued)
      }
      Task { [weak self] in await self?.flush() }
    }
    switch resolution {
    case .synced: return .synced
    case .queued: return .queued
    case .rejected(let message): throw Rejected(message: message)
    }
  }

  /// Sends queued writes oldest first. A write that fails for a non-Convex reason stays
  /// queued and is skipped for this pass, so one bad entry can't block the rest.
  public func flush() async {
    guard !flushing else { return }
    flushing = true
    defer {
      flushing = false
      for id in Array(waiters.keys) { resolve(id, .queued) }
    }
    var tried = Set<String>()
    while canSend(), let next = pending.first(where: { !tried.contains($0.id) }) {
      tried.insert(next.id)
      do {
        try await send(next)
        remove(next.id)
        resolve(next.id, .synced)
      } catch let rejected as Rejected {
        remove(next.id)
        if !resolve(next.id, .rejected(rejected.message)) {
          failures.append(Failure(id: next.id, name: next.name, message: rejected.message))
          changed()
        }
      } catch {
        if let index = pending.firstIndex(where: { $0.id == next.id }) {
          pending[index].attempts += 1
          changed()
        }
        resolve(next.id, .queued)
      }
    }
  }

  public func dismissFailures() {
    failures.removeAll()
    changed()
  }

  private func remove(_ id: String) {
    pending.removeAll { $0.id == id }
    changed()
  }

  @discardableResult
  private func resolve(_ id: String, _ resolution: Resolution) -> Bool {
    guard let waiter = waiters.removeValue(forKey: id) else { return false }
    waiter.resume(returning: resolution)
    return true
  }

  private func changed() {
    persist()
    onChange?()
  }

  private func persist() {
    guard let fileURL, let data = try? JSONEncoder().encode(pending) else { return }
    try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? data.write(to: fileURL, options: .atomic)
  }
}

/// Last-known query results on disk, keyed by a caller-chosen string.
public struct LastKnownCache: Sendable {
  public let directory: URL

  public init(directory: URL) {
    self.directory = directory
  }

  public func read(_ key: String) -> ConvexValue? {
    guard let data = try? Data(contentsOf: fileURL(for: key)) else { return nil }
    return try? JSONDecoder().decode(ConvexValue.self, from: data)
  }

  public func contains(_ key: String) -> Bool {
    FileManager.default.fileExists(atPath: fileURL(for: key).path)
  }

  public func write(_ key: String, _ value: ConvexValue) {
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try? Data(value.jsonString().utf8).write(to: fileURL(for: key), options: .atomic)
  }

  /// On sign-out, so the next account never sees the last one's baby.
  public func clear() {
    try? FileManager.default.removeItem(at: directory)
  }

  func fileURL(for key: String) -> URL {
    // FNV-1a: stable across launches, unlike `Hasher`.
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in key.utf8 {
      hash ^= UInt64(byte)
      hash = hash &* 0x100_0000_01b3
    }
    return directory.appendingPathComponent(String(hash, radix: 16) + ".json")
  }
}

/// What the sync banner says, if anything.
public enum SyncStatus {
  public struct Message: Equatable, Sendable {
    public enum Action: Equatable, Sendable { case retry, dismiss }
    public let text: String
    public let action: Action?
  }

  public static func message(reachable: Bool, pending: Int, failure: String?) -> Message? {
    if let failure {
      return Message(text: "A log couldn't be saved: \(failure)", action: .dismiss)
    }
    let entries = pending == 1 ? "1 log" : "\(pending) logs"
    if !reachable {
      if pending > 0 {
        return Message(text: "Offline. \(entries) saved, will sync.", action: .retry)
      }
      return Message(text: "Offline. Showing what's saved on this phone.", action: .retry)
    }
    if pending > 0 {
      return Message(text: "\(entries) saved, will sync.", action: .retry)
    }
    return nil
  }
}
