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
  static var convexURL: String { value("ConvexDeploymentURL") }
  static let appGroup = "group.com.nickmcblain.babysteps"

  static var isComplete: Bool { !clerkPublishableKey.isEmpty && !convexURL.isEmpty }

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

  @ObservationIgnored let client: ConvexClientWithAuth<String>
  @ObservationIgnored private let provider: ClerkConvexTemplateAuthProvider
  @ObservationIgnored private var bag = Set<AnyCancellable>()

  init(deploymentUrl: String) {
    provider = ClerkConvexTemplateAuthProvider()
    client = ConvexClientWithAuth(deploymentUrl: deploymentUrl, authProvider: provider)
    client.authState
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        switch state {
        case .loading: self?.auth = .loading
        case .unauthenticated: self?.auth = .signedOut
        case .authenticated: self?.auth = .signedIn
        }
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

  func action<R: Decodable>(_ call: ConvexCall<R>) async throws -> R {
    try await client.action(call.name, with: call.encodedArgs)
  }

  func signOut() async {
    await client.logout()
  }
}

/// A reactive query result. Bind it from a view with `.task(id: call.key) { await live.bind(call, convex) }`.
@MainActor
@Observable
final class Live<Value: Decodable> {
  private(set) var value: Value?
  private(set) var error: String?

  var isLoading: Bool { value == nil && error == nil }

  init(_ initial: Value? = nil) { value = initial }

  /// Runs until the calling task is cancelled (view disappears or the key changes).
  func bind(_ call: ConvexCall<Value>, _ convex: ConvexService) async {
    error = nil
    do {
      for try await next in convex.subscribe(call).values {
        value = next
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
  static func from(_ error: Error, fallback: String = "Something went wrong. Try again.") -> String {
    if let client = error as? ClientError {
      switch client {
      case .ConvexError(let data):
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
