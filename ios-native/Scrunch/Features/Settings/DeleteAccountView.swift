import ClerkKit
import ScrunchCore
import SwiftUI
import UserNotifications
import WidgetKit

struct DeleteAccountView: View {
  let onExportFirst: () -> Void

  @Environment(ConvexService.self) private var convex
  @Environment(Clerk.self) private var clerk
  @Environment(ActiveBabyStore.self) private var activeBaby
  @State private var confirmation = ""
  @State private var error: String?

  static let confirmWord = "DELETE"

  private var confirmed: Bool {
    confirmation.trimmingCharacters(in: .whitespaces).uppercased() == Self.confirmWord
  }

  var body: some View {
    SettingsSheetScaffold(title: "Delete account") {
      Subtitle("This permanently deletes your Scrunch account. It can't be undone.")
      Card {
        Text("What happens").font(.app(.bold, 17)).foregroundStyle(C.ink)
        BulletList(items: [
          "Babies only you can see are deleted, with every feed, sleep, nappy, growth entry and Ask chat.",
          "Babies you share with a partner stay with them. Your access, Ask chats and remembered facts are removed. Logs you added stay so their record is complete.",
          "Your sign-in is deleted, including any linked Apple or Google account.",
          "Information on this phone, like the widget, reminders and any running timer, is cleared.",
        ], tint: C.danger)
        Text("If you subscribe through the App Store, deleting your account doesn't cancel it. Cancel in your iPhone's Settings first.")
          .font(.app(.body, 13)).foregroundStyle(C.muted).lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
      }
      SecondaryButton(label: "Export my data first", action: onExportFirst)

      FormField(label: "Type \(Self.confirmWord) to confirm", text: $confirmation, placeholder: Self.confirmWord)
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()
      PrimaryButton(label: "Delete my account", disabled: !confirmed, tint: C.danger) { await deleteAccount() }
      if let error {
        Text(error).font(.app(.medium, 14)).foregroundStyle(C.danger).fixedSize(horizontal: false, vertical: true)
      }
    }
    .interactiveDismissDisabled(confirmed)
  }

  private func deleteAccount() async {
    error = nil
    do {
      let result = try await convex.action(API.account.deleteAccount())
      if !result.signInDeleted, let user = clerk.user {
        _ = try await user.delete()
      }
    } catch {
      self.error = "Your account wasn't fully deleted: \(UserMessage.from(error)) Try again\(PrivacyConfig.supportEmail.map { ", or email \($0)" } ?? "")."
      return
    }
    await LocalData.clear(activeBaby: activeBaby)
    try? await clerk.auth.signOut()
  }
}

/// Everything Scrunch keeps on the device for the signed-in person.
@MainActor
enum LocalData {
  static func clear(activeBaby: ActiveBabyStore) async {
    await TimerStore.shared.stop()
    activeBaby.clear()
    GlanceStore.defaults.removeObject(forKey: GlanceSnapshot.storageKey)
    UserDefaults.standard.removeObject(forKey: AIDisclosure.consentKey)
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    WidgetCenter.shared.reloadAllTimelines()
  }
}
