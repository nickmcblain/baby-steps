import ScrunchCore
import SwiftUI

/// One line above every signed-in screen when Convex is unreachable, logs are waiting
/// to sync, or a queued log was refused. Hidden otherwise.
struct SyncBanner: View {
  @Environment(ConvexService.self) private var convex
  /// Debounced so a normal save or a brief reconnect doesn't flash the banner.
  @State private var offline = false
  @State private var waiting = false

  private var message: SyncStatus.Message? {
    SyncStatus.message(reachable: !offline, pending: waiting ? convex.pendingLogs : 0, failure: convex.syncFailure)
  }

  var body: some View {
    Group {
      if let message {
        HStack(spacing: 10) {
          Image(systemName: offline ? "wifi.slash" : "arrow.triangle.2.circlepath")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(C.ink)
            .accessibilityHidden(true)
          Text(message.text)
            .font(.app(.medium, 13))
            .foregroundStyle(C.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
          switch message.action {
          case .retry:
            Button("Retry") { Task { await convex.retry(manual: true) } }
              .font(.app(.bold, 13))
              .foregroundStyle(C.ink)
          case .dismiss:
            Button("OK") { convex.dismissSyncFailure() }
              .font(.app(.bold, 13))
              .foregroundStyle(C.ink)
          case nil:
            EmptyView()
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(C.amberSoft)
        .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .animation(.easeOut(duration: 0.2), value: message)
    .task(id: convex.reachable) {
      offline = await Self.settle(!convex.reachable)
    }
    .task(id: convex.pendingLogs > 0) {
      waiting = await Self.settle(convex.pendingLogs > 0)
    }
  }

  /// True only once `condition` has held for a few seconds; false straight away.
  private static func settle(_ condition: Bool) async -> Bool {
    guard condition else { return false }
    try? await Task.sleep(for: .seconds(3))
    return !Task.isCancelled
  }
}
