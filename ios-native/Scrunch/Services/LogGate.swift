import ConvexMobile
import Foundation
import Observation
import ScrunchCore
import WidgetKit

/// The one place the free allowance is applied in the app. Every log typed in Scrunch is saved
/// through `save`, which checks `FreeAllowance` first and Convex has the final say. Past the
/// allowance it shows the paywall and waits: after a purchase the same save runs again, so
/// nothing the parent typed is lost; after closing it nothing is saved and the form stays as it was.
@MainActor
@Observable
final class LogGate {
  struct Paywall: Identifiable {
    let id = UUID()
    var type: LogType?
    /// Logs from Siri, widgets or the Live Activity waiting for a subscription.
    var heldCount = 0
  }

  private(set) var allowances: [BabyID: BabyAllowance] = [:]
  var paywall: Paywall?
  private(set) var held: [PendingLog] = []

  @ObservationIgnored let entitlements: Entitlements
  @ObservationIgnored var undo: UndoCenter?
  /// Closes any sheet in the way of the paywall; returns true if it closed one.
  @ObservationIgnored var clearSheets: (() -> Bool)?
  @ObservationIgnored private var waiting: CheckedContinuation<Bool, Never>?
  @ObservationIgnored private var heldShown: Set<String> = []
  @ObservationIgnored private let defaults = UserDefaults.standard
  private static let hintedKey = "allowance.hinted"

  init(entitlements: Entitlements) {
    self.entitlements = entitlements
  }

  func unlocked(_ babyId: BabyID) -> Bool {
    entitlements.subscribed || allowances[babyId]?.unlocked == true
  }

  /// Ask and patterns: open until the first free allowance runs out.
  func featureOpen(_ babyId: BabyID) -> Bool {
    unlocked(babyId) || allowances[babyId]?.trialUsed != true
  }

  /// Keeps the allowance current while signed in, and mirrors it for Siri and widgets.
  func bind(_ convex: ConvexService) async {
    do {
      for try await response in convex.subscribe(API.allowance.mine()).values {
        apply(response.babies)
      }
    } catch {}
  }

  func apply(_ babies: [BabyAllowance]) {
    let previous = allowances
    allowances = Dictionary(babies.map { ($0.babyId, $0) }, uniquingKeysWith: { first, _ in first })
    mirror()
    hintIfNeeded(previous: previous)
  }

  func mirror() {
    let shared = SharedAllowance(babies: allowances, subscribed: entitlements.subscribed)
    guard shared != SharedAllowance.load(from: GlanceStore.defaults) else { return }
    shared.save(to: GlanceStore.defaults)
    WidgetCenter.shared.reloadAllTimelines()
  }

  /// Saves a log typed in the app. Returns nil when the parent closed the paywall instead.
  /// `type` is nil when it isn't known until Convex has read the note (voice logs) or for sleep.
  func save<T>(_ type: LogType?, babyId: BabyID, _ run: () async throws -> T) async throws -> T? {
    if let type, let allowance = allowances[babyId],
       !FreeAllowance.canLog(type, used: allowance.used(type), unlocked: unlocked(babyId)) {
      guard await askToSubscribe(type) else { return nil }
    }
    do {
      return try await run()
    } catch let error where Self.refusal(error) != nil {
      if entitlements.subscribed {
        await entitlements.resync()
      } else {
        guard case .freeLimit(let type) = Self.refusal(error), await askToSubscribe(type) else { return nil }
      }
      do {
        return try await run()
      } catch let error where Self.refusal(error) != nil {
        throw GateError.notConfirmed
      }
    }
  }

  /// Shows the paywall and waits for it to close. True if the parent is now subscribed.
  func askToSubscribe(_ type: LogType?) async -> Bool {
    guard waiting == nil else { return false }
    if clearSheets?() == true { try? await Task.sleep(for: .milliseconds(600)) }
    paywall = Paywall(type: type, heldCount: held.count)
    return await withCheckedContinuation { waiting = $0 }
  }

  /// The paywall sheet's onDismiss.
  func paywallClosed() {
    let subscribed = entitlements.subscribed
    paywall = nil
    mirror()
    if let waiting {
      self.waiting = nil
      waiting.resume(returning: subscribed)
    }
    if subscribed, !held.isEmpty { Task { await sendHeld() } }
  }

  // MARK: Logs held from outside the app

  func reloadHeld() {
    held = QuickLogStore.held.all
  }

  /// When the app comes forward: the paywall once per held log, saying what is waiting, or
  /// because a locked widget button asked for it.
  func presentHeldIfNeeded() {
    reloadHeld()
    let requested = GlanceStore.defaults.bool(forKey: openPaywallKey)
    GlanceStore.defaults.removeObject(forKey: openPaywallKey)
    let fresh = held.filter { !heldShown.contains($0.id) }
    guard !fresh.isEmpty || requested, paywall == nil, waiting == nil else { return }
    if entitlements.subscribed {
      if !held.isEmpty { Task { await sendHeld() } }
      return
    }
    heldShown.formUnion(fresh.map(\.id))
    paywall = Paywall(type: fresh.first.flatMap { FreeAllowance.type(for: $0.log) }, heldCount: held.count)
  }

  func sendHeld() async {
    for log in QuickLogStore.held.all {
      QuickLogStore.queue.enqueue(log)
      QuickLogStore.held.remove(id: log.id)
    }
    reloadHeld()
    await PendingLogSender.shared.send()
  }

  func discardHeld() {
    for log in QuickLogStore.held.all { QuickLogStore.held.remove(id: log.id) }
    reloadHeld()
  }

  // MARK: Hint

  /// "3 of 5 free feeds left", at most once per type, after the saved toast has gone.
  private func hintIfNeeded(previous: [BabyID: BabyAllowance]) {
    guard !entitlements.subscribed else { return }
    var hinted = Set(defaults.stringArray(forKey: Self.hintedKey) ?? [])
    for (babyId, allowance) in allowances where !allowance.unlocked {
      for type in LogType.allCases where !hinted.contains(type.rawValue) {
        let used = allowance.used(type)
        guard let before = previous[babyId], used > before.used(type),
              let hint = FreeAllowance.hint(type, used: used) else { continue }
        hinted.insert(type.rawValue)
        defaults.set(Array(hinted), forKey: Self.hintedKey)
        showWhenQuiet(hint)
        return
      }
    }
  }

  private func showWhenQuiet(_ message: String) {
    Task { [weak self] in
      for _ in 0..<20 where self?.undo?.toast != nil {
        try? await Task.sleep(for: .seconds(1))
      }
      self?.undo?.show(UndoCenter.Toast(message: message))
    }
  }

  static func refusal(_ error: Error) -> ServerRefusal? {
    if let refusal = error as? ServerRefusal { return refusal }
    guard case ClientError.ConvexError(let data) = error else { return nil }
    return ServerRefusal(errorData: data)
  }

  enum GateError: LocalizedError {
    case notConfirmed
    var errorDescription: String? {
      "Your subscription is still being confirmed. Try saving again in a moment."
    }
  }
}
