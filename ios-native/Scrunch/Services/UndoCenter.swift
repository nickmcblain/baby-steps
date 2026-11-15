import Foundation
import Observation
import ScrunchCore
import SwiftUI

/// One toast at a time with Undo and, for fresh logs, "−5 min" chips. Deletes are deferred:
/// the row hides at once and the mutation only runs when the toast goes away.
@MainActor
@Observable
final class UndoCenter {
  struct Toast: Identifiable {
    let id = UUID()
    var message: String
    var undo: (@MainActor () async -> Void)?
    /// Moves the log earlier by N minutes; returns the new message.
    var shift: (@MainActor (Int) async -> String?)?
    /// Runs when the toast expires, is replaced, or the app goes to the background.
    var commit: (@MainActor () async -> Void)?
  }

  private static let lifetime: Duration = .seconds(6)

  private(set) var toast: Toast?
  private(set) var hiddenEventIds: Set<EventID> = []
  @ObservationIgnored private var expiry: Task<Void, Never>?

  func show(_ next: Toast) {
    let previous = toast
    toast = next
    restartExpiry()
    AccessibilityNotification.Announcement(next.message).post()
    if let commit = previous?.commit { Task { await commit() } }
  }

  func undo() async {
    guard let current = toast else { return }
    clear()
    await current.undo?()
  }

  func shift(_ minutes: Int) async {
    guard let current = toast, let shift = current.shift else { return }
    restartExpiry()
    if let message = await shift(minutes), toast?.id == current.id {
      toast?.message = message
      restartExpiry()
    }
  }

  /// Ends the toast and keeps whatever it reported.
  func settle() {
    guard let current = toast else { return }
    clear()
    if let commit = current.commit { Task { await commit() } }
  }

  func delete(_ event: Event, convex: ConvexService) {
    let id = event.id
    hiddenEventIds.insert(id)
    show(Toast(
      message: "\(EventCopy.kindLabel(event, now: Date().epochMs)) deleted",
      undo: { [weak self] in _ = self?.hiddenEventIds.remove(id) },
      commit: { [weak self] in
        do {
          try await convex.mutation(API.events.remove(id))
        } catch {
          self?.hiddenEventIds.remove(id)
          self?.show(Toast(message: String(localized: "Couldn’t delete. Try again.")))
        }
      }
    ))
  }

  private func clear() {
    expiry?.cancel()
    toast = nil
  }

  private func restartExpiry() {
    expiry?.cancel()
    let id = toast?.id
    expiry = Task { [weak self] in
      try? await Task.sleep(for: Self.lifetime)
      guard !Task.isCancelled, let self, self.toast?.id == id else { return }
      self.settle()
    }
  }
}

struct UndoToastView: View {
  @Environment(UndoCenter.self) private var undo

  var body: some View {
    if let toast = undo.toast {
      HStack(spacing: 8) {
        Text(toast.message)
          .font(.app(.bold, 15))
          .foregroundStyle(C.onInk)
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)
        if toast.shift != nil {
          ForEach(QuickLog.shiftMinutes.prefix(1), id: \.self) { minutes in
            chip("−\(minutes) min", label: "Move \(minutes) minutes earlier") { await undo.shift(minutes) }
          }
        }
        if toast.undo != nil {
          chip("Undo", label: "Undo") { await undo.undo() }
        }
      }
      .padding(.leading, 18)
      .padding(.trailing, 8)
      .padding(.vertical, 8)
      .frame(minHeight: 56)
      .background(C.ink, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
      .cardShadow(opacity: 0.2)
      .padding(.horizontal, 16)
      .transition(.move(edge: .bottom).combined(with: .opacity))
      .id(toast.id)
      .gesture(DragGesture(minimumDistance: 12).onEnded { value in
        if value.translation.height > 20 { undo.settle() }
      })
    }
  }

  private func chip(_ text: LocalizedStringKey, label: LocalizedStringKey, action: @escaping () async -> Void) -> some View {
    Button { Task { await action() } } label: {
      Text(text)
        .font(.app(.bold, 15))
        .foregroundStyle(C.teal)
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(PressScale())
    .accessibilityLabel(label)
  }
}
