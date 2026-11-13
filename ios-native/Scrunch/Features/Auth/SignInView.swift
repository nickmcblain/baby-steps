import ClerkKitUI
import SwiftUI

/// Port of app/(auth)/sign-in.tsx: teal hero over Clerk's native AuthView.
struct SignInView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        Circle().fill(C.teal).frame(width: 56, height: 56).padding(.bottom, 8)
        Text("SCRUNCH")
          .font(.app(.bold, 14))
          .tracking(0.6)
          .foregroundStyle(C.tealDark)
        Text("Keep the little hours in one place.")
          .font(.app(.displayBold, 32, relativeTo: .largeTitle))
          .foregroundStyle(C.ink)
          .lineSpacing(2)
      }
      .padding(.horizontal, 24)
      .padding(.top, 28)
      .padding(.bottom, 12)

      AuthView(isDismissible: false)
        .background(C.card)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 36, topTrailingRadius: 36, style: .continuous))
        .padding(.top, 8)
        .ignoresSafeArea(edges: .bottom)
    }
    .background(C.bg.ignoresSafeArea())
  }
}
