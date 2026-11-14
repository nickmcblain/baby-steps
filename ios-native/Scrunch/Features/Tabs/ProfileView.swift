import ClerkKit
import ClerkKitUI
import ScrunchCore
import SwiftUI

/// Port of app/(app)/(tabs)/profile.tsx.
struct ProfileView: View {
  @Environment(ConvexService.self) private var convex
  @Environment(Clerk.self) private var clerk
  @State private var user = Live<ScrunchCore.User?>()

  private var email: String {
    user.value??.email ?? clerk.user?.primaryEmailAddress?.emailAddress ?? "—"
  }

  var body: some View {
    ScreenScaffold(showsBack: false, clearDock: true) {
      HStack {
        ScreenTitle("Profile")
        Spacer()
        UserButton()
          .accessibilityLabel("Account")
          .accessibilityInputLabels(["Account", "Sign out", "Manage account"])
      }
      Card {
        row("Email", email)
        Rectangle().fill(C.line).frame(height: 1)
        row("Subscription", "Not subscribed")
      }
    }
    .task { await user.bind(API.users.current(), convex) }
  }

  private func row(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label).font(.app(.medium, 13)).foregroundStyle(C.muted)
      Text(value).font(.app(.bold, 17)).foregroundStyle(C.ink)
    }
    .accessibilityElement(children: .combine)
  }
}
