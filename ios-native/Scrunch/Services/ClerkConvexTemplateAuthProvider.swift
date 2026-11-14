import Foundation
import ClerkKit
@preconcurrency import ConvexMobile

/// Same shape as `ClerkConvexAuthProvider` from clerk-convex-swift 0.1.0, but asks Clerk for
/// the `convex` JWT template, exactly like the RN app (`ConvexProviderWithClerk`). The official
/// bridge sends the default session token, which only carries `aud: "convex"` once the Clerk
/// dashboard Convex integration is activated. See docs/swift-migration/PLAN.md.
@MainActor
final class ClerkConvexTemplateAuthProvider: AuthProvider {
  typealias T = String

  static let template = "convex"

  private var onIdToken: (@Sendable (String?) -> Void)?
  private var refreshTask: Task<Void, Never>?
  private var sessionSyncTask: Task<Void, Never>?
  private weak var client: ConvexClientWithAuth<String>?

  func bind(client: ConvexClientWithAuth<String>) {
    self.client = client
    sessionSyncTask?.cancel()
    sessionSyncTask = Task { [weak self] in
      guard let self else { return }
      await self.sync(old: nil, new: Clerk.shared.session)
      for await event in Clerk.shared.auth.events {
        guard !Task.isCancelled else { break }
        if case .sessionChanged(let old, let new) = event {
          await self.sync(old: old, new: new)
        }
      }
    }
  }

  func login(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> String {
    try await authenticate(onIdToken)
  }

  func loginFromCache(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> String {
    try await authenticate(onIdToken)
  }

  func logout() async throws {
    refreshTask?.cancel()
    refreshTask = nil
    onIdToken = nil
    try await Clerk.shared.auth.signOut()
  }

  nonisolated func extractIdToken(from authResult: String) -> String { authResult }

  private func authenticate(_ onIdToken: @Sendable @escaping (String?) -> Void) async throws -> String {
    self.onIdToken = onIdToken
    let token = try await fetchToken(skipCache: false)
    startRefreshListener()
    return token
  }

  private func fetchToken(skipCache: Bool) async throws -> String {
    guard Clerk.shared.isLoaded else { throw AuthError.clerkNotLoaded }
    guard let session = Clerk.shared.session, session.status == .active else { throw AuthError.noActiveSession }
    let options = Session.GetTokenOptions(template: Self.template, skipCache: skipCache)
    guard let token = try await session.getToken(options) else { throw AuthError.noToken }
    return token
  }

  /// Clerk's `tokenRefreshed` event carries the default session token, not the template one,
  /// so on each refresh we fetch a fresh template token and hand that to Convex instead.
  private func startRefreshListener() {
    refreshTask?.cancel()
    refreshTask = Task { [weak self] in
      for await event in Clerk.shared.auth.events {
        guard !Task.isCancelled, let self else { break }
        if case .tokenRefreshed = event, let token = try? await self.fetchToken(skipCache: false) {
          self.onIdToken?(token)
        }
      }
    }
  }

  private func sync(old: Session?, new: Session?) async {
    guard let client else { return }
    if new?.status == .active, old?.status != .active || old?.id != new?.id {
      _ = await client.loginFromCache()
    } else if old?.id != nil, new == nil {
      await client.logout()
    }
  }

  enum AuthError: LocalizedError {
    case clerkNotLoaded, noActiveSession, noToken

    var errorDescription: String? {
      switch self {
      case .clerkNotLoaded: "Clerk has not finished loading."
      case .noActiveSession: "No active Clerk session."
      case .noToken: "Clerk did not return a Convex token."
      }
    }
  }
}
