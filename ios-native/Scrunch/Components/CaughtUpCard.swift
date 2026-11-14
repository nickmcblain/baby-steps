import ScrunchCore
import SwiftUI

/// A quiet "nothing needs doing" moment for Home. Never shown when a feed or nap is close.
struct CaughtUpCard: View {
  let state: CaughtUp

  var body: some View {
    HStack(spacing: 14) {
      IconWell(systemImage: "checkmark.heart.fill", tint: C.tealSoft, size: 44, ink: C.tealDark)
      VStack(alignment: .leading, spacing: 2) {
        Text("All caught up")
          .font(.app(.display, 18, relativeTo: .headline))
          .foregroundStyle(C.ink)
        Text(state.detail())
          .font(.app(.body, 14, relativeTo: .subheadline))
          .foregroundStyle(C.muted)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(C.card, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
    .cardShadow()
    .accessibilityElement(children: .combine)
  }
}
