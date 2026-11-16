import ScrunchCore
import SwiftUI

/// "Right now" card: plain-words insights, each tappable, with Ask underneath.
struct InsightCard: View {
  let insights: [Insight]
  var caughtUp = false
  let onOpen: (Insight.Kind) -> Void
  let onAsk: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 6) {
        Text("Right now")
          .font(.app(.bold, 13))
          .foregroundStyle(C.muted)
        Spacer(minLength: 8)
        if caughtUp {
          Image(systemName: "checkmark.heart.fill")
            .font(.system(size: 12, weight: .bold))
            .accessibilityHidden(true)
          Text("All caught up. Rest if you can.")
            .font(.app(.bold, 13))
        }
      }
      .foregroundStyle(C.tealDark)
      .padding(.horizontal, 16)
      .padding(.top, 14)
      .padding(.bottom, 4)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)
      ForEach(insights, id: \.kind) { insight in
        Button { onOpen(insight.kind) } label: { row(insight) }
          .buttonStyle(.plain)
          .accessibilityElement(children: .combine)
          .accessibilityAddTraits(.isButton)
      }
      AskEntryRow(action: onAsk)
        .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 0.5) }
    }
    .background(C.card, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
    .cardShadow()
  }

  private func row(_ insight: Insight) -> some View {
    let style = Self.style(insight.kind)
    return HStack(alignment: .top, spacing: 12) {
      IconWell(systemImage: style.symbol, tint: style.tint, size: 32, ink: style.ink)
      VStack(alignment: .leading, spacing: 2) {
        Text(insight.headline).font(.app(.bold, 15)).foregroundStyle(C.ink)
        Text(insight.detail).font(.app(.body, 13)).foregroundStyle(C.muted)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .multilineTextAlignment(.leading)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .contentShape(Rectangle())
  }

  static func style(_ kind: Insight.Kind) -> (symbol: String, tint: Color, ink: Color) {
    switch kind {
    case .nextFeed: ("drop.fill", C.tealSoft, C.tealDark)
    case .breastSide: ("arrow.left.arrow.right", C.tealSoft, C.tealDark)
    case .lastNappy: ("circle.grid.2x2.fill", C.peachSoft, C.peach)
    case .awake: ("sun.max.fill", C.purpleSoft, C.purple)
    case .tonightTog: ("moon.stars.fill", C.amberSoft, C.ink)
    }
  }
}

/// Full-width way into Ask, saying where its answers come from.
struct AskEntryRow: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        IconWell(systemImage: "bubble.left.and.text.bubble.right.fill", tint: C.teal, size: 32)
        VStack(alignment: .leading, spacing: 2) {
          Text(AskSafety.entryTitle).font(.app(.bold, 15)).foregroundStyle(C.ink)
          Text(AskSafety.entrySubtitle).font(.app(.body, 13)).foregroundStyle(C.muted)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(C.muted)
          .accessibilityHidden(true)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
  }
}
