import Foundation
import Observation
import ScrunchCore
import StoreKit

/// The subscription, straight from StoreKit 2. StoreKit is the source of truth on the device;
/// each verified transaction is also sent to Convex, which checks Apple's signature and then
/// lets logs past the free allowance through.
@MainActor
@Observable
final class Entitlements {
  private(set) var status: PlanStatus?
  private(set) var products: [Product] = []
  /// False until the first StoreKit read finishes, so gated screens don't flash the upsell.
  private(set) var loaded = false

  var subscribed: Bool { status != nil }

  @ObservationIgnored private(set) var appAccountToken: UUID?
  @ObservationIgnored private var sync: ((String) async -> Void)?
  @ObservationIgnored private var synced: Set<String> = []
  @ObservationIgnored private var updates: Task<Void, Never>?

  func start() {
    guard updates == nil else { return }
    updates = Task { [weak self] in
      for await result in Transaction.updates {
        if case .verified(let transaction) = result { await transaction.finish() }
        await self?.refresh()
      }
    }
    Task { await refresh() }
  }

  /// Ties purchases to the signed-in Scrunch account and starts syncing them to Convex.
  func connect(_ convex: ConvexService) async {
    guard let token = try? await convex.mutation(API.subscriptions.accountToken()) else { return }
    appAccountToken = UUID(uuidString: token)
    synced = []
    sync = { jws in _ = try? await convex.action(API.appStore.syncTransaction(jws)) }
    await refresh()
  }

  func refresh() async {
    if products.isEmpty {
      products = (try? await Product.products(for: Subscription.productIDs)) ?? []
    }
    var best: PlanStatus?
    for await result in Transaction.currentEntitlements {
      guard case .verified(let transaction) = result,
            Subscription.productIDs.contains(transaction.productID),
            transaction.revocationDate == nil
      else { continue }
      let status = PlanStatus(
        productID: transaction.productID,
        expiresAt: transaction.expirationDate,
        willAutoRenew: await transaction.willAutoRenew,
        familyShared: transaction.ownershipType == .familyShared
      )
      if best == nil || (status.expiresAt ?? .distantFuture) > (best?.expiresAt ?? .distantFuture) {
        best = status
      }
      if let sync, synced.insert(result.jwsRepresentation).inserted {
        await sync(result.jwsRepresentation)
      }
    }
    status = best
    loaded = true
  }

  /// Sends every current transaction to Convex again, for when it refuses a log StoreKit says is paid for.
  func resync() async {
    synced = []
    await refresh()
  }

  /// Settings' Restore purchases. Asks the App Store to sync, which may prompt for the Apple ID password.
  func restore() async throws {
    try await AppStore.sync()
    await resync()
  }

  /// Purchases from `SubscriptionStoreView` arrive here rather than through `Transaction.updates`.
  func handlePurchase(_ result: Result<Product.PurchaseResult, Error>) async -> Bool {
    guard case .success(.success(let verification)) = result, case .verified(let transaction) = verification else { return false }
    await transaction.finish()
    await refresh()
    return true
  }

  func renewalPrice(for status: PlanStatus?) -> String? {
    guard let status, let product = products.first(where: { $0.id == status.productID }),
          let period = product.subscription?.subscriptionPeriod
    else { return nil }
    return Subscription.renewalPrice(product.displayPrice, value: period.value, unit: period.unit.periodUnit)
  }
}

private extension Transaction {
  var willAutoRenew: Bool {
    get async {
      guard let status = await subscriptionStatus, case .verified(let renewal) = status.renewalInfo else { return false }
      return renewal.willAutoRenew
    }
  }
}

private extension Product.SubscriptionPeriod.Unit {
  var periodUnit: Subscription.PeriodUnit {
    switch self {
    case .day: .day
    case .week: .week
    case .month: .month
    case .year: .year
    @unknown default: .month
    }
  }
}
