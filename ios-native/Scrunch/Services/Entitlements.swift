import Foundation
import Observation
import ScrunchCore
import StoreKit
import UserNotifications

/// Scrunch Plus, straight from StoreKit 2. StoreKit is the source of truth on the device;
/// each verified transaction is also sent to Convex, which checks Apple's signature.
@MainActor
@Observable
final class Entitlements {
  private(set) var status: PlusStatus?
  private(set) var products: [Product] = []
  private(set) var trialEligible = false
  /// False until the first StoreKit read finishes, so gated screens don't flash the upsell.
  private(set) var loaded = false

  var hasPlus: Bool { status != nil }

  @ObservationIgnored private(set) var appAccountToken: UUID?
  @ObservationIgnored private var sync: ((String) async -> Void)?
  @ObservationIgnored private var synced: Set<String> = []
  @ObservationIgnored private var updates: Task<Void, Never>?

  var monthly: Product? { products.first { $0.id == Plus.monthlyProductID } }

  /// "2 weeks" when the parent can still start the free trial.
  var trialLength: String? {
    guard trialEligible, let offer = monthly?.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
    return Plus.duration(value: offer.period.value, unit: offer.period.unit.plusUnit)
  }

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
      products = (try? await Product.products(for: Plus.productIDs)) ?? []
    }
    var best: PlusStatus?
    for await result in Transaction.currentEntitlements {
      guard case .verified(let transaction) = result,
            Plus.productIDs.contains(transaction.productID),
            transaction.revocationDate == nil
      else { continue }
      let status = PlusStatus(
        productID: transaction.productID,
        expiresAt: transaction.expirationDate,
        inTrial: transaction.isIntroductoryOffer,
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
    trialEligible = await monthly?.subscription?.isEligibleForIntroOffer ?? false
    loaded = true
    await TrialReminderScheduler.reconcile(status: status, renewalPrice: renewalPrice(for: status))
  }

  /// Settings' Restore purchases. Asks the App Store to sync, which may prompt for the Apple ID password.
  func restore() async throws {
    try await AppStore.sync()
    await refresh()
  }

  /// Purchases from `SubscriptionStoreView` arrive here rather than through `Transaction.updates`.
  func handlePurchase(_ result: Result<Product.PurchaseResult, Error>) async -> Bool {
    guard case .success(.success(let verification)) = result, case .verified(let transaction) = verification else { return false }
    await transaction.finish()
    await refresh()
    return true
  }

  func renewalPrice(for status: PlusStatus?) -> String? {
    guard let status, let product = products.first(where: { $0.id == status.productID }),
          let period = product.subscription?.subscriptionPeriod
    else { return nil }
    return Plus.renewalPrice(product.displayPrice, value: period.value, unit: period.unit.plusUnit)
  }
}

private extension Transaction {
  var isIntroductoryOffer: Bool {
    if #available(iOS 17.2, *) {
      return offer?.type == .introductory
    } else {
      return offerType == .introductory
    }
  }

  var willAutoRenew: Bool {
    get async {
      guard let status = await subscriptionStatus, case .verified(let renewal) = status.renewalInfo else { return false }
      return renewal.willAutoRenew
    }
  }
}

private extension Product.SubscriptionPeriod.Unit {
  var plusUnit: Plus.PeriodUnit {
    switch self {
    case .day: .day
    case .week: .week
    case .month: .month
    case .year: .year
    @unknown default: .month
    }
  }
}

/// The one trial-ending reminder. Off until the parent opts in.
@MainActor
enum TrialReminderScheduler {
  private static let optInKey = "plus.trialReminderOptIn"

  static var isOptedIn: Bool { UserDefaults.standard.bool(forKey: optInKey) }

  /// Returns false if notifications are not allowed.
  @discardableResult
  static func setOptIn(_ on: Bool, status: PlusStatus?, renewalPrice: String?) async -> Bool {
    if on, !(await Reminders.ensurePermission()) {
      UserDefaults.standard.set(false, forKey: optInKey)
      return false
    }
    UserDefaults.standard.set(on, forKey: optInKey)
    await reconcile(status: status, renewalPrice: renewalPrice)
    return true
  }

  static func reconcile(status: PlusStatus?, renewalPrice: String?, now: Date = Date()) async {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [TrialReminder.identifier])
    guard isOptedIn, let status, status.inTrial, status.willAutoRenew, !status.familyShared,
          let end = status.expiresAt,
          let fireAt = TrialReminder.fireDate(trialEndsAt: end, now: now)
    else { return }
    let content = UNMutableNotificationContent()
    content.title = TrialReminder.title
    content.body = TrialReminder.body(trialEndsAt: end, renewalPrice: renewalPrice)
    content.sound = .default
    content.userInfo = ["kind": "plus-trial-reminder"]
    let request = UNNotificationRequest(
      identifier: TrialReminder.identifier,
      content: content,
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, fireAt.timeIntervalSince(now)), repeats: false)
    )
    try? await center.add(request)
  }
}
