import Foundation
import Observation
import ScrunchCore

/// Sharing a baby needs the carer's own subscription, for both creating a code and joining with one.
/// Shows the paywall first when they don't have one, then carries on by itself after a purchase.
@MainActor @Observable
final class SharingGate {
  enum Reason: String, Identifiable {
    case invite, join
    var id: String { rawValue }
  }

  var paywall: Reason?
  @ObservationIgnored var entitlements: Entitlements?
  @ObservationIgnored private var waiting: CheckedContinuation<Bool, Never>?

  init(entitlements: Entitlements? = nil) {
    self.entitlements = entitlements
  }

  private var subscribed: Bool { entitlements?.subscribed ?? false }

  /// Runs `action`, which Convex refuses for carers without a subscription. Returns nil if they
  /// closed the paywall without subscribing.
  func perform<T>(_ reason: Reason, _ action: () async throws -> T) async throws -> T? {
    if !subscribed {
      guard await askToSubscribe(reason) else { return nil }
    }
    do {
      return try await action()
    } catch let error where LogGate.refusal(error) == .sharingNeedsSubscription {
      await entitlements?.resync()
      if !subscribed {
        guard await askToSubscribe(reason) else { return nil }
      }
      return try await action()
    }
  }

  /// The paywall sheet's onDismiss.
  func paywallClosed() {
    paywall = nil
    if let waiting {
      self.waiting = nil
      waiting.resume(returning: subscribed)
    }
  }

  private func askToSubscribe(_ reason: Reason) async -> Bool {
    guard waiting == nil else { return false }
    paywall = reason
    return await withCheckedContinuation { waiting = $0 }
  }
}

/// Sharing copy, from Localizable.xcstrings.
enum SharingCopy {
  static var eachCarer: String {
    String(localized: "sharing.eachCarer", comment: "Shown wherever a baby can be shared, and on the paywall")
  }

  static var paywallTitle: String {
    String(localized: "sharing.paywall.title", comment: "Paywall title when sharing needs a subscription")
  }

  static var joinSubtitle: String {
    String(localized: "sharing.paywall.join", comment: "Paywall subtitle when joining a shared baby with a code")
  }

  static var inviteSubtitle: String {
    String(localized: "sharing.paywall.invite", comment: "Paywall subtitle when creating a share code")
  }

  static var subscribeAndJoin: String {
    String(localized: "sharing.join.subscribe", comment: "Button in the join sheet after closing the paywall")
  }
}
