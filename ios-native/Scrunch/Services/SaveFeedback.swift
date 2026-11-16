import Observation
import ScrunchCore
import SwiftUI

/// One soft haptic and a brief, calm line after every successful save.
/// Save screens dismiss themselves, so the confirmation lives above the navigation stack.
@MainActor
@Observable
final class SaveFeedback {
  struct Note: Equatable, Identifiable {
    let id = UUID()
    let text: String
  }

  private(set) var note: Note?
  private(set) var tick = 0

  @ObservationIgnored private var names: [BabyID: String] = [:]
  @ObservationIgnored private var hideTask: Task<Void, Never>?

  func remember(_ babies: [Baby]) {
    names = Dictionary(babies.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
  }

  func babyName(_ babyId: BabyID) -> String? { names[babyId] }

  func logged(_ kind: EventKind, babyId: BabyID) {
    show(SaveCopy.logged(kind, babyName: names[babyId]))
  }

  /// Haptic only, for saves whose confirmation is already the undo toast.
  func haptic() { tick += 1 }

  func show(_ text: String) {
    note = Note(text: text)
    tick += 1
    AccessibilityNotification.Announcement(text).post()
    hideTask?.cancel()
    hideTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(2.4))
      guard !Task.isCancelled else { return }
      self?.note = nil
    }
  }
}

private struct SaveToast: View {
  let text: String

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "checkmark")
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(C.onAccent)
        .frame(width: 24, height: 24)
        .background(C.teal, in: Circle())
        .accessibilityHidden(true)
      Text(text)
        .font(.app(.bold, 15))
        .foregroundStyle(C.ink)
        .lineLimit(2)
    }
    .padding(.leading, 10)
    .padding(.trailing, 18)
    .padding(.vertical, 10)
    .background(C.card, in: Capsule())
    .cardShadow(opacity: 0.12)
    .padding(.horizontal, 20)
  }
}

private struct SaveFeedbackHost: ViewModifier {
  @Environment(SaveFeedback.self) private var feedback
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .top) {
        if let note = feedback.note {
          SaveToast(text: note.text)
            .id(note.id)
            .padding(.top, 6)
            .allowsHitTesting(false)
            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        }
      }
      .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.15), value: feedback.note)
      .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: feedback.tick)
  }
}

extension View {
  /// Hosts the save toast and haptic. Apply once, around the navigation stack.
  func saveFeedbackHost() -> some View { modifier(SaveFeedbackHost()) }
}
