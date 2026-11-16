import Combine
import ConvexMobile
import Foundation
import Observation
import ScrunchCore

extension ConvexValue: ConvexEncodable {
  public func convexEncode() throws -> String { jsonString() }
}

private extension ConvexCall {
  var encodedArgs: [String: ConvexEncodable?] { args.mapValues { Optional($0 as ConvexEncodable) } }
}

enum AppConfig {
  static var clerkPublishableKey: String { value("ClerkPublishableKey") }
  static var convexURL: String {
    #if DEBUG
    // UI tests point Convex at an unreachable host to exercise the offline path.
    if let url = ProcessInfo.processInfo.environment["SCRUNCH_CONVEX_URL"] { return url }
    #endif
    return value("ConvexDeploymentURL")
  }
  static let appGroup = "group.com.nickmcblain.babysteps"

  /// xcconfig treats `//` as a comment, so an unescaped `https://...` arrives as `https:`.
  /// Requiring a host catches that instead of hanging on "Connecting…".
  static var isComplete: Bool {
    !clerkPublishableKey.isEmpty && URL(string: convexURL)?.host?.isEmpty == false
  }

  private static func value(_ key: String) -> String {
    let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    // An unset xcconfig variable leaves the literal "$(NAME)" behind.
    return raw.hasPrefix("$(") ? "" : raw.trimmingCharacters(in: .whitespaces)
  }
}

/// Owns the one `ConvexClientWithAuth` and mirrors its auth state for SwiftUI.
@MainActor
@Observable
final class ConvexService {
  enum Auth { case loading, signedOut, signedIn }

  private(set) var auth: Auth = .loading
  /// ConvexMobile only reports changes, and connects lazily on first use, so this starts false.
  private(set) var socketConnected = false
  private(set) var pendingLogs = 0
  private(set) var syncFailure: String?

  /// Convex is answering: authed and the socket is up.
  var reachable: Bool { auth == .signedIn && socketConnected }

  @ObservationIgnored let client: ConvexClientWithAuth<String>
  @ObservationIgnored let cache: LastKnownCache
  /// Set at launch: a previous session left a babies list, so tabs can render before auth.
  @ObservationIgnored let hasLastKnownState: Bool
  @ObservationIgnored private let provider: ClerkConvexTemplateAuthProvider
  @ObservationIgnored private let outbox: Outbox
  @ObservationIgnored private let results: SyncedLogIds
  @ObservationIgnored private var bag = Set<AnyCancellable>()
  @ObservationIgnored private var retrying = false

  init(deploymentUrl: String) {
    let provider = ClerkConvexTemplateAuthProvider()
    let client = ConvexClientWithAuth(deploymentUrl: deploymentUrl, authProvider: provider)
    self.provider = provider
    self.client = client
    let files = FileManager.default
    let cache = LastKnownCache(directory: files.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("LastKnown"))
    self.cache = cache
    hasLastKnownState = cache.contains(API.babies.list().key)

    let results = SyncedLogIds()
    self.results = results
    outbox = Outbox(fileURL: files.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Outbox/pending.json")) { entry in
      do {
        let id: EventID = try await client.mutation(entry.name, with: entry.args.mapValues { Optional($0 as ConvexEncodable) })
        results.ids[entry.id] = id
      } catch let error as ClientError {
        if case .ConvexError(let data) = error { throw Outbox.Rejected(message: UserMessage.from(error), data: data) }
        throw error
      }
    }
    outbox.canSend = { [weak self] in self?.auth == .signedIn }
    outbox.onChange = { [weak self] in self?.syncOutboxState() }
    syncOutboxState()

    client.authState
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        guard let self else { return }
        switch state {
        case .loading: auth = .loading
        case .unauthenticated: auth = .signedOut
        case .authenticated:
          auth = .signedIn
          Task { await self.outbox.flush() }
        }
      }
      .store(in: &bag)
    client.watchWebSocketState()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        guard let self else { return }
        socketConnected = state == .connected
        if socketConnected { Task { await self.retry() } }
      }
      .store(in: &bag)
    provider.bind(client: client)
  }

  func subscribe<R: Decodable>(_ call: ConvexCall<R>) -> AnyPublisher<R, ClientError> {
    client.subscribe(to: call.name, with: call.encodedArgs, yielding: R.self)
  }

  @discardableResult
  func mutation<R: Decodable>(_ call: ConvexCall<R>) async throws -> R {
    try await client.mutation(call.name, with: call.encodedArgs)
  }

  /// What happened to a log sent through the outbox.
  enum LogOutcome: Equatable {
    /// Convex saved it; the id lets the caller offer Undo.
    case synced(EventID)
    /// Kept on this phone and sent when Convex is reachable.
    case queued
  }

  /// Event logs go through the outbox: saved on the phone first, so a dropped connection
  /// or a killed app can't lose them, and replays can't duplicate them. A refusal
  /// (e.g. past the free allowance) throws `Outbox.Rejected`, which `LogGate` understands.
  @discardableResult
  func log(_ call: ConvexCall<EventID>) async throws -> LogOutcome {
    let clientId = UUID().uuidString.lowercased()
    let outcome = try await outbox.submit(call.name, call.args, now: Date().epochMs, id: clientId)
    guard outcome == .synced, let id = results.ids.removeValue(forKey: clientId) else { return .queued }
    return .synced(id)
  }

  func action<R: Decodable>(_ call: ConvexCall<R>) async throws -> R {
    try await client.action(call.name, with: call.encodedArgs)
  }

  /// Reconnects auth if it dropped (e.g. the token fetch failed offline) and resends queued logs.
  /// `manual` (a Retry tap) also restarts a login that is still hanging.
  func retry(manual: Bool = false) async {
    if auth == .signedOut && !retrying || manual && auth != .signedIn {
      retrying = true
      _ = await client.loginFromCache()
      retrying = false
    }
    await outbox.flush()
  }

  func dismissSyncFailure() {
    outbox.dismissFailures()
  }

  /// Returns once Convex auth is ready. Subscribing earlier would fail with "Not authenticated".
  func untilSignedIn() async {
    if auth == .signedIn { return }
    for await state in client.authState.values {
      if case .authenticated = state { return }
    }
  }

  func signOut() async {
    PendingLogSender.publish(babies: [], activeId: nil)
    await client.logout()
  }

  private func syncOutboxState() {
    pendingLogs = outbox.pending.count
    syncFailure = outbox.failures.last?.message
  }
}

/// A reactive query result. Bind it from a view with `.task(id: call.key) { await live.bind(call, convex) }`.
@MainActor
@Observable
final class Live<Value: Decodable> {
  private(set) var value: Value?
  private(set) var error: String?
  /// The value came from Convex this session, not the on-disk copy.
  private(set) var isFresh = false

  var isLoading: Bool { value == nil && error == nil }

  init(_ initial: Value? = nil) { value = initial }

  /// Runs until the calling task is cancelled (view disappears or the key changes).
  /// With a `cacheKey`, the last result is shown straight away and kept on disk.
  func bind(_ call: ConvexCall<Value>, _ convex: ConvexService, cacheKey: String? = nil) async {
    error = nil
    if let cacheKey, let cached: Value = try? convex.cache.read(cacheKey)?.decode() {
      value = cached
    }
    await convex.untilSignedIn()
    guard !Task.isCancelled else { return }
    do {
      if let cacheKey {
        let cache = convex.cache
        for try await raw in convex.subscribe(ConvexCall<ConvexValue>(call.name, call.args)).values {
          value = try raw.decode()
          isFresh = true
          Task.detached(priority: .utility) { cache.write(cacheKey, raw) }
        }
      } else {
        for try await next in convex.subscribe(call).values {
          value = next
          isFresh = true
        }
      }
    } catch {
      self.error = UserMessage.from(error)
    }
  }

  func reset() {
    value = nil
    error = nil
  }
}

enum UserMessage {
  /// Turns `ConvexError("No baby matches that code")` and friends into the plain message,
  /// the same text RN showed via `err.message`.
  static func from(_ error: Error, fallback: String = String(localized: "Something went wrong. Try again.")) -> String {
    if let client = error as? ClientError {
      switch client {
      case .ConvexError(let data):
        if let refusal = ServerRefusal(errorData: data) { return refusal.message }
        if let text = try? JSONDecoder().decode(String.self, from: Data(data.utf8)) { return text }
        if let object = try? JSONDecoder().decode([String: String].self, from: Data(data.utf8)),
           let message = object["message"] { return message }
        return data
      case .ServerError(let msg), .InternalError(let msg):
        return cleanServerMessage(msg) ?? fallback
      }
    }
    let text = error.localizedDescription
    return text.isEmpty ? fallback : text
  }

  /// "[CONVEX M(babies:joinByCode)] [Request ID: …] Server Error\nUncaught Error: X" → "X"
  private static func cleanServerMessage(_ msg: String) -> String? {
    if let range = msg.range(of: "Uncaught Error: ") {
      let tail = msg[range.upperBound...]
      return String(tail.split(separator: "\n").first ?? tail)
    }
    return msg.isEmpty ? nil : msg
  }
}

/// Server ids of logs the outbox sent, keyed by `clientId`, until `log` collects them.
@MainActor
private final class SyncedLogIds {
  var ids: [String: EventID] = [:]
}
