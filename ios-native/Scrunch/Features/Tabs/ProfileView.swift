import ClerkKit
import ClerkKitUI
import ScrunchCore
import SwiftUI

/// The Profile tab: account, subscription, partner sharing, data and privacy, help.
struct ProfileView: View {
  enum Sheet: String, Identifiable {
    case account, joinPartner, export, aboutAI, deleteAccount
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
  @Environment(Entitlements.self) private var entitlements
  @State private var sharing = SharingGate()
  @State private var inviting: BabyID?
  @State private var shareError: String?
  @AppStorage(MilestonesCard.visibleKey) private var showMilestones = true
  @AppStorage(WeightPreference.storageKey) private var weightPreference = WeightPreference.automatic

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
        SubscriptionRow(babyId: activeBaby.babyId)
          .padding(.horizontal, 10)
          .padding(.vertical, 10)
      }

      SettingsSection(title: "Partner sharing") {
        ForEach(babies.value ?? []) { baby in
          if let code = baby.inviteCode {
            ShareLink(item: PartnerInvite.message(babyName: baby.name, code: code)) {
              SettingsRowLabel(title: "Invite to \(baby.name)", value: code, systemImage: "person.2.fill", tint: C.purple, accessory: "square.and.arrow.up")
            }
            .buttonStyle(PressScale())
          } else {
            SettingsRow(title: "Invite to \(baby.name)", value: inviting == baby.id ? "…" : nil, systemImage: "person.2.fill", tint: C.purple) {
              Task { await invite(baby) }
            }
            .disabled(inviting != nil)
            .accessibilityHint(SharingCopy.eachCarer)
          }
          SettingsDivider()
        }
        SettingsRow(title: "Join with a code", systemImage: "figure.and.child.holdinghands", tint: C.purple) { sheet = .joinPartner }
      }
      VStack(alignment: .leading, spacing: 6) {
        if let shareError {
          Text(shareError).font(.app(.medium, 14)).foregroundStyle(C.danger)
        }
        Text(SharingCopy.eachCarer).font(.app(.body, 13)).foregroundStyle(C.muted)
          .fixedSize(horizontal: false, vertical: true)
      }

      SettingsSection(title: "Preferences") {
        VStack(alignment: .leading, spacing: 8) {
          Text("Show weights in").font(.app(.bold, 16)).foregroundStyle(C.ink)
          Picker("Show weights in", selection: weightUnit) {
            Text("kg").tag(WeightUnit.kg)
            Text("lb & oz").tag(WeightUnit.lb)
          }
          .pickerStyle(.segmented)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        SettingsDivider()
        Toggle(isOn: $showMilestones) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Little firsts").font(.app(.bold, 16)).foregroundStyle(C.ink)
            Text("An optional card for first smiles and the like. Never sends reminders.")
              .font(.app(.body, 14)).foregroundStyle(C.muted)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .tint(C.teal)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
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
    .onAppear { sharing.entitlements = entitlements }
    .sheet(item: Bindable(sharing).paywall, onDismiss: sharing.paywallClosed) { reason in
      PaywallView(sharing: reason)
    }
    .sheet(item: $sheet) { sheet in
      content(for: sheet)
        .presentationCornerRadius(32)
        .presentationBackground(C.bg)
    }
  }

  /// Starts on the region's unit; picking one pins it.
  private var weightUnit: Binding<WeightUnit> {
    Binding(
      get: { DisplayFormat(weightPreference: weightPreference).weightUnit },
      set: { weightPreference = $0 == .lb ? .lbOz : .kg }
    )
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
        Text(displayName).font(.app(.bold, 18)).foregroundStyle(C.ink).fixedSize(horizontal: false, vertical: true)
        Text(email).font(.app(.medium, 14)).foregroundStyle(C.muted).fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 4)
    .accessibilityElement(children: .combine)
  }

  /// The code appears once Convex has made it; the babies query is live.
  private func invite(_ baby: Baby) async {
    inviting = baby.id
    shareError = nil
    sharing.entitlements = entitlements
    do {
      _ = try await sharing.perform(.invite) { try await convex.mutation(API.babies.createInvite(baby.id)) }
    } catch {
      shareError = UserMessage.from(error, fallback: String(localized: "Couldn't make a share code. Try again."))
    }
    inviting = nil
  }

  @ViewBuilder
  private func content(for sheet: Sheet) -> some View {
    switch sheet {
    case .account:
      UserProfileView()
    case .joinPartner:
      JoinPartnerSheet { id in
        self.sheet = nil
        activeBaby.select(id)
        router.popToRoot(tab: .home)
      }
      .presentationDetents([.height(360)])
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
