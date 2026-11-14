import ConvexMobile
import Foundation
import ScrunchCore
import WidgetKit

/// Sends logs queued by intents and widget buttons (see QuickLogStore) with the app's
/// Clerk-authenticated Convex client. Runs when an intent fires in the app's process, when
/// the app signs in, and each time it comes to the foreground.
@MainActor
final class PendingLogSender {
  static let shared = PendingLogSender()

  var convex: ConvexService?
  /// Called after a queued log is held for a subscription, so the app can show the paywall.
  var onHeld: (() -> Void)?
  private var sending = false

  func send() async {
    guard let convex, !sending, !QuickLogStore.queue.all.isEmpty else { return }
    sending = true
    defer { sending = false }

    // Siri can launch the app in the background, before Clerk and Convex have connected.
    for _ in 0..<20 where convex.auth != .signedIn {
      try? await Task.sleep(for: .milliseconds(500))
    }
    guard convex.auth == .signedIn else { return }

    let queue = QuickLogStore.queue
    var held = false
    defer { if held { onHeld?() } }
    for log in queue.all {
      do {
        _ = try await convex.mutation(log.call)
        queue.remove(id: log.id)
      } catch let error where LogGate.refusal(error) != nil {
        // Past the free allowance (a partner may have used the last ones): keep it for after subscribing.
        QuickLogStore.held.enqueue(log)
        queue.remove(id: log.id)
        held = true
      } catch ClientError.ConvexError {
        // The server rejected it (e.g. the baby was removed); retrying won't help.
        queue.remove(id: log.id)
      } catch {
        break
      }
    }
  }

  /// Keep the intents' baby list in step with the signed-in account.
  static func publish(babies: [Baby], activeId: BabyID?) {
    let shared = SharedBabies(babies: babies.map { .init(id: $0.id, name: $0.name) }, activeId: activeId)
    if shared.save(to: GlanceStore.defaults) {
      WidgetCenter.shared.reloadAllTimelines()
    }
  }
}
