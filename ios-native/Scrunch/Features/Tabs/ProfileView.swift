import ClerkKit
import ClerkKitUI
import ScrunchCore
import SwiftUI

/// The Profile tab: account, subscription, partner sharing, data and privacy, help.
struct ProfileView: View {
  enum Sheet: String, Identifiable {
    case account, subscription, joinPartner, export, aboutAI, deleteAccount
    var id: String { rawValue }
  }

  @Environment(ConvexService.self) private var convex
  @Environment(Clerk.self) private var clerk
  @Environment(AppRouter.self) private var router
  @Environment(ActiveBabyStore.self) private var activeBaby
  @State private var user = Live<ScrunchCore.User?>()
  @State private var babies = Live<[Baby]>()
  @State private var sheet: Sheet?
  @State private var confirmSignOut = false

  private var email: String {
    user.value??.email ?? clerk.user?.primaryEmailAddress?.emailAddress ?? "—"
  }

  private var displayName: String {
    let clerkName = [clerk.user?.firstName, clerk.user?.lastName].compactMap { $0 }.joined(separator: " ")
    return clerkName.isEmpty ? (user.value??.name ?? "You") : clerkName
  }

  var body: some View {
    ScreenScaffold(showsBack: false, clearDock: true) {
      ScreenTitle("Profile")
      header

      SettingsSection(title: "Account") {
        SettingsRow(title: "Sign-in and security", systemImage: "person.badge.key.fill", tint: C.sky) { sheet = .account }
      }

      SettingsSection(title: "Subscription") {
        SettingsRow(title: "Scrunch Plus", value: "Not subscribed", systemImage: "star.fill", tint: C.amber) { sheet = .subscription }
      }

      SettingsSection(title: "Partner sharing") {
        ForEach(babies.value ?? []) { baby in
          ShareLink(item: PartnerInvite.message(babyName: baby.name, code: baby.inviteCode)) {
            SettingsRowLabel(title: "Invite to \(baby.name)", value: baby.inviteCode, systemImage: "person.2.fill", tint: C.purple, accessory: "square.and.arrow.up")
          }
          .buttonStyle(PressScale())
          SettingsDivider()
        }
        SettingsRow(title: "Join with a code", systemImage: "figure.and.child.holdinghands", tint: C.purple) { sheet = .joinPartner }
      }

      SettingsSection(title: "Data and privacy") {
        SettingsRow(title: "Export care log", value: "PDF or CSV", systemImage: "square.and.arrow.down.fill", tint: C.teal) { sheet = .export }
        SettingsDivider()
        SettingsRow(title: "About Ask and Speak (AI)", systemImage: "sparkles", tint: C.tealDark) { sheet = .aboutAI }
        SettingsDivider()
        SettingsLinkRow(title: "Privacy policy", systemImage: "hand.raised.fill", tint: C.sky, url: PrivacyConfig.policyURL)
      }

      SettingsSection(title: "Help") {
        SettingsLinkRow(title: "Contact us", value: PrivacyConfig.supportEmail, systemImage: "envelope.fill", tint: C.peach, url: PrivacyConfig.supportURL)
        SettingsDivider()
        SettingsLinkRow(title: "Urgent health worries: NHS 111", systemImage: "cross.case.fill", tint: C.rose, url: PrivacyConfig.nhs111)
      }

      SettingsSection {
        SettingsRow(title: "Sign out", systemImage: "rectangle.portrait.and.arrow.right", tint: C.muted) { confirmSignOut = true }
        SettingsDivider()
        SettingsRow(title: "Delete account", systemImage: "trash.fill", destructive: true) { sheet = .deleteAccount }
      }

      Text("Scrunch \(PrivacyConfig.appVersion). Not a medical service.")
        .font(.app(.body, 12))
        .foregroundStyle(C.muted)
        .frame(maxWidth: .infinity)
    }
    .task { await user.bind(API.users.current(), convex) }
    .task { await babies.bind(API.babies.list(), convex) }
    .confirmationDialog("Sign out of Scrunch?", isPresented: $confirmSignOut, titleVisibility: .visible) {
      Button("Sign out", role: .destructive) {
        Task {
          await LocalData.clear(activeBaby: activeBaby)
          try? await clerk.auth.signOut()
        }
      }
    } message: {
      Text("Your logs stay saved to your account. The widget, reminders and any running timer on this phone are cleared.")
    }
    .sheet(item: $sheet) { sheet in
      content(for: sheet)
        .presentationCornerRadius(32)
        .presentationBackground(C.bg)
    }
  }

  private var header: some View {
    HStack(spacing: 14) {
      AsyncImage(url: clerk.user.flatMap { URL(string: $0.imageUrl) }) { image in
        image.resizable().scaledToFill()
      } placeholder: {
        C.line
      }
      .frame(width: 52, height: 52)
      .clipShape(Circle())
      .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(displayName).font(.app(.bold, 18)).foregroundStyle(C.ink).lineLimit(1)
        Text(email).font(.app(.medium, 14)).foregroundStyle(C.muted).lineLimit(1)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 4)
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private func content(for sheet: Sheet) -> some View {
    switch sheet {
    case .account:
      UserProfileView()
    case .subscription:
      SubscriptionEntryView()
        .presentationDetents([.medium])
    case .joinPartner:
      JoinPartnerSheet { id in
        self.sheet = nil
        activeBaby.select(id)
        router.popToRoot(tab: .home)
      }
      .presentationDetents([.height(260)])
      .presentationDragIndicator(.visible)
    case .export:
      ExportCareLogView()
    case .aboutAI:
      AboutAIView()
    case .deleteAccount:
      DeleteAccountView { self.sheet = .export }
    }
  }
}

/// Entry point for the StoreKit paywall.
struct SubscriptionEntryView: View {
  var body: some View {
    SettingsSheetScaffold(title: "Scrunch Plus") {
      Subtitle("Subscriptions aren't available yet. Everything in Scrunch works without one.")
    }
  }
}
