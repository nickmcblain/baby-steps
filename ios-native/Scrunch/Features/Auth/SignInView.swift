import ClerkKitUI
import SwiftUI

/// Port of app/(auth)/sign-in.tsx: teal hero over Clerk's native AuthView.
struct SignInView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        Image("BrandMark")
          .resizable()
          .frame(width: 56, height: 56)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          .padding(.bottom, 8)
          .accessibilityHidden(true)
        Text("Scrunch")
          .font(.app(.displayBold, 18))
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
