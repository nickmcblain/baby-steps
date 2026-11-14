import ScrunchCore
import SwiftUI

/// Port of components/AddLogSheet.tsx: 11 log tiles plus the Speak tile, three across.
struct AddLogSheet: View {
  let babyId: BabyID?

  @Environment(AppRouter.self) private var router
  @Environment(ConvexService.self) private var convex
  @Environment(SaveFeedback.self) private var saveFeedback
  @State private var voice = VoiceLogRecorder()
  @Environment(UndoCenter.self) private var undo

  private struct Tile: Identifiable {
    let screen: BabyScreen
    let label: String
    let tint: Color
    let symbol: String
    var id: String { label }
  }

  /// Most-logged first; Speak sits in the second row.
  private let topTiles: [Tile] = [
    Tile(screen: .feedTimer, label: "Feed", tint: C.teal, symbol: "drop.fill"),
    Tile(screen: .sleepTimer, label: "Sleep", tint: C.purple, symbol: "moon.fill"),
    Tile(screen: .nappy, label: "Nappy", tint: C.peach, symbol: "circle.grid.2x2.fill"),
    Tile(screen: .tummyTimer, label: "Tummy", tint: C.sky, symbol: "figure.arms.open"),
    Tile(screen: .pumpTimer, label: "Pump", tint: C.tealDark, symbol: "drop.halffull"),
  ]

  private let moreTiles: [Tile] = [
    Tile(screen: .medicine, label: "Medicine", tint: C.amber, symbol: "pills.fill"),
    Tile(screen: .potty, label: "Potty", tint: C.peach, symbol: "toilet.fill"),
    Tile(screen: .activity, label: "Activity", tint: C.purple, symbol: "figure.play"),
    Tile(screen: .customEvent, label: "Note", tint: C.rose, symbol: "calendar.badge.plus"),
    Tile(screen: .clothing, label: "Clothing", tint: C.amber, symbol: "tshirt.fill"),
    Tile(screen: .ask(question: nil), label: "Ask", tint: C.teal, symbol: "bubble.left.and.text.bubble.right.fill"),
  ]

  /// Fits four rows of three without scrolling.
  static let detentHeight: CGFloat = 460

  /// Idle Speak well: darker than ink-on-light, still fine for a white glyph.
  private let speakWell = Color(hex: 0x3E4654)

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
          ForEach(topTiles) { tileButton($0) }
          Button { Task { await speak() } } label: {
            tileLabel(voice.recording ? "Listening" : "Speak") {
              ZStack {
                Circle().fill(voice.recording ? C.danger : speakWell).frame(width: 40, height: 40)
                if voice.busy {
                  ProgressView().tint(.white)
                } else {
                  Image(systemName: "mic.fill").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                }
              }
            }
          }
          .buttonStyle(PressScale())
          .disabled(voice.busy)
          .accessibilityLabel(voice.recording ? "Stop and send" : "Speak a log or question")
          ForEach(moreTiles) { tileButton($0) }
        }
        if let status = voice.status {
          Text(status)
            .font(.app(.medium, 14))
            .foregroundStyle(C.muted)
            .multilineTextAlignment(.center)
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 24)
      .padding(.bottom, 16)
    }
    .onDisappear { voice.cancel() }
    .alert(item: $voice.alert) { alert in
      Alert(title: Text(alert.title), message: Text(alert.message))
    }
  }

  private func tileButton(_ tile: Tile) -> some View {
    Button { go(tile.screen) } label: {
      tileLabel(tile.label) { IconWell(systemImage: tile.symbol, tint: tile.tint) }
    }
    .buttonStyle(PressScale())
  }

  private func tileLabel<Icon: View>(_ label: String, @ViewBuilder icon: () -> Icon) -> some View {
    VStack(spacing: 8) {
      icon()
      Text(label).font(.app(.bold, 14)).foregroundStyle(C.ink)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .padding(.horizontal, 6)
    .background(C.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .cardShadow()
  }

  private func go(_ screen: BabyScreen) {
    if voice.recording || voice.busy { return }
    router.addLogOpen = false
    guard let babyId else {
      router.popToRoot(tab: .kids)
      return
    }
    router.push(babyId, screen)
  }

  private func speak() async {
    guard let babyId else {
      router.addLogOpen = false
      router.popToRoot(tab: .kids)
      return
    }
    let result = await voice.toggle(babyId: babyId, convex: convex) { handle($0, babyId: babyId) }
    if let result { handle(result, babyId: babyId) }
  }

  private func handle(_ result: VoiceLogResult, babyId: BabyID) {
    if result.handoff == "ask" {
      router.addLogOpen = false
      router.push(babyId, .ask(question: result.transcript))
      return
    }
    router.addLogOpen = false
    undo.show(UndoCenter.Toast(message: result.confirmation))
    saveFeedback.haptic()
  }
}
