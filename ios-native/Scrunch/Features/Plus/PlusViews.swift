import ScrunchCore
import StoreKit
import SwiftUI

/// Apple's subscription view: StoreKit shows the price, trial length and renewal period.
/// Only ever opened by the parent (a Plus feature or Settings), never pushed on its own.
struct PlusPaywallView: View {
  var feature: Plus.Feature?

  @Environment(Entitlements.self) private var entitlements
  @Environment(\.dismiss) private var dismiss
  @State private var offerReminder = false

  var body: some View {
    let token = entitlements.appAccountToken
    SubscriptionStoreView(productIDs: Plus.productIDs) {
      PlusMarketing(feature: feature)
    }
    .subscriptionStoreControlStyle(.buttons)
    .subscriptionStoreButtonLabel(.multiline)
    .storeButton(.visible, for: .restorePurchases)
    .storeButton(.visible, for: .cancellation)
    .subscriptionStorePolicyDestination(url: Plus.termsOfUseURL, for: .termsOfService)
    .inAppPurchaseOptions { _ in token.map { [.appAccountToken($0)] } ?? [] }
    .onInAppPurchaseCompletion { _, result in await completed(result) }
    .alert(TrialReminder.consentTitle, isPresented: $offerReminder) {
      Button("Remind me") {
        Task {
          await TrialReminderScheduler.setOptIn(
            true, status: entitlements.status, renewalPrice: entitlements.renewalPrice(for: entitlements.status)
          )
          dismiss()
        }
      }
      Button("No thanks", role: .cancel) { dismiss() }
    } message: {
      Text(TrialReminder.consentMessage)
    }
    .tint(C.teal)
  }

  private func completed(_ result: Result<Product.PurchaseResult, Error>) async {
    guard await entitlements.handlePurchase(result) else { return }
    if let status = entitlements.status, status.inTrial, status.willAutoRenew, !TrialReminderScheduler.isOptedIn {
      offerReminder = true
    } else {
      dismiss()
    }
  }
}

private struct PlusMarketing: View {
  let feature: Plus.Feature?

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Scrunch Plus")
        .font(.app(.displayBold, 30, relativeTo: .largeTitle))
        .foregroundStyle(C.ink)
        .accessibilityAddTraits(.isHeader)
      Subtitle(feature?.pitch ?? "Extras for when you want to understand the days, not just log them.")
      VStack(alignment: .leading, spacing: 8) {
        ForEach(Plus.includes, id: \.self) { item in
          PlusBullet(text: item, symbol: "checkmark.circle.fill", tint: C.teal)
        }
      }
      Text(Plus.alwaysFreeSummary)
        .font(.app(.medium, 14))
        .foregroundStyle(C.tealDark)
        .fixedSize(horizontal: false, vertical: true)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(C.tealSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      Text(Plus.renewalTerms)
        .font(.app(.body, 12, relativeTo: .caption))
        .foregroundStyle(C.muted)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 24)
    .padding(.top, 24)
  }
}

private struct PlusBullet: View {
  let text: String
  let symbol: String
  let tint: Color

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: symbol).foregroundStyle(tint).accessibilityHidden(true)
      Text(text)
        .font(.app(.medium, 15))
        .foregroundStyle(C.ink)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

/// What never needs Plus. Shown wherever we mention Plus, so nobody wonders if logging will be taken away.
private struct PlusFreeList: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Always free").font(.app(.bold, 15)).foregroundStyle(C.tealDark)
      ForEach(Plus.alwaysFree, id: \.self) { item in
        PlusBullet(text: item, symbol: "heart.fill", tint: C.tealDark)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(C.tealSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }
}

/// Shows a Plus screen to subscribers, and a calm explanation with a way in for everyone else.
struct PlusGate<Content: View>: View {
  let feature: Plus.Feature
  @ViewBuilder var content: Content

  @Environment(Entitlements.self) private var entitlements
  @State private var showPaywall = false

  var body: some View {
    Group {
      if entitlements.hasPlus {
        content
      } else if !entitlements.loaded {
        LoadingView()
      } else {
        ScreenScaffold {
          Text("Scrunch Plus").font(.app(.bold, 14)).foregroundStyle(C.tealDark)
          ScreenTitle(feature.title)
          Subtitle(feature.pitch)
          PlusFreeList()
          PrimaryButton(label: Plus.callToAction(trialLength: entitlements.trialLength)) { showPaywall = true }
          if entitlements.trialLength != nil {
            Text("Nothing to pay during the trial. We can remind you before it ends.")
              .font(.app(.body, 14))
              .foregroundStyle(C.muted)
              .frame(maxWidth: .infinity)
              .multilineTextAlignment(.center)
          }
        }
      }
    }
    // Outside the branches, so the sheet survives the switch to `content` after a purchase.
    .sheet(isPresented: $showPaywall) { PlusPaywallView(feature: feature) }
  }
}

/// The Subscription row in Profile/Settings: status, a way into Plus, Manage and Restore.
struct PlusSubscriptionRow: View {
  @Environment(Entitlements.self) private var entitlements
  @State private var showPaywall = false
  @State private var showManage = false
  @State private var restoring = false
  @State private var reminderOn = TrialReminderScheduler.isOptedIn
  @State private var alert: FormAlert?

  var body: some View {
    let status = entitlements.status
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Subscription").font(.app(.medium, 13)).foregroundStyle(C.muted)
        Text(status?.planName ?? "Not subscribed").font(.app(.bold, 17)).foregroundStyle(C.ink)
        Text(status?.summary() ?? "Logging, timers and widgets are free. Plus adds Ask and patterns.")
          .font(.app(.body, 14))
          .foregroundStyle(C.muted)
          .fixedSize(horizontal: false, vertical: true)
      }
      .accessibilityElement(children: .combine)

      if status == nil {
        PrimaryButton(label: Plus.callToAction(trialLength: entitlements.trialLength)) { showPaywall = true }
      }

      if let status, status.inTrial, status.willAutoRenew, !status.familyShared {
        Toggle(isOn: $reminderOn) {
          Text("Remind me 2 days before the trial ends").font(.app(.medium, 15)).foregroundStyle(C.ink)
        }
        .tint(C.teal)
        .onChange(of: reminderOn) { _, on in
          Task {
            let ok = await TrialReminderScheduler.setOptIn(on, status: status, renewalPrice: entitlements.renewalPrice(for: status))
            if !ok {
              reminderOn = false
              alert = FormAlert(title: "Notifications are off", message: "Turn on notifications for Scrunch in Settings to get the reminder.")
            }
          }
        }
      }

      HStack {
        linkButton("Manage subscription") { showManage = true }
        Spacer()
        linkButton(restoring ? "Restoring…" : "Restore purchases") { Task { await restore() } }
          .disabled(restoring)
      }
    }
    .manageSubscriptionsSheet(isPresented: $showManage)
    .onChange(of: showManage) { _, open in
      if !open { Task { await entitlements.refresh() } }
    }
    .sheet(isPresented: $showPaywall) { PlusPaywallView() }
    .formAlert($alert)
  }

  private func linkButton(_ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(label).font(.app(.bold, 15)).foregroundStyle(C.tealDark).frame(minHeight: 44)
    }
  }

  private func restore() async {
    restoring = true
    defer { restoring = false }
    do {
      try await entitlements.restore()
      alert = entitlements.hasPlus
        ? FormAlert(title: "Plus restored", message: "Thanks for supporting Scrunch.")
        : FormAlert(title: "Nothing to restore", message: "We couldn't find a Scrunch Plus subscription for this Apple ID.")
    } catch StoreKitError.userCancelled {
      return
    } catch {
      alert = FormAlert(title: "Could not restore", message: UserMessage.from(error, fallback: "Check your connection and try again."))
    }
  }
}
