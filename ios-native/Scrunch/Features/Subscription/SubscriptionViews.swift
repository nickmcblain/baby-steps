import ScrunchCore
import StoreKit
import SwiftUI

/// Apple's subscription view: StoreKit shows the prices and renewal periods. It appears when a
/// log goes past the free allowance, from a locked Ask or patterns screen, or from Profile.
struct PaywallView: View {
  var type: LogType?
  var feature: Subscription.Feature?
  var heldCount = 0

  @Environment(Entitlements.self) private var entitlements
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    let token = entitlements.appAccountToken
    SubscriptionStoreView(productIDs: Subscription.productIDs) {
      PaywallMarketing(type: type, feature: feature, heldCount: heldCount)
    }
    .subscriptionStoreControlStyle(.buttons)
    .subscriptionStoreButtonLabel(.multiline)
    .storeButton(.visible, for: .restorePurchases)
    .storeButton(.visible, for: .cancellation)
    .subscriptionStorePolicyDestination(url: Subscription.termsOfUseURL, for: .termsOfService)
    .inAppPurchaseOptions { _ in token.map { [.appAccountToken($0)] } ?? [] }
    .onInAppPurchaseCompletion { _, result in
      if await entitlements.handlePurchase(result) { dismiss() }
    }
    .tint(C.teal)
  }
}

private struct PaywallMarketing: View {
  let type: LogType?
  let feature: Subscription.Feature?
  let heldCount: Int

  private var title: String {
    if let feature { return feature.title }
    return FreeAllowance.paywallTitle(type)
  }

  private var subtitle: String {
    if heldCount > 0 {
      let entries = heldCount == 1 ? "1 entry from Siri or a widget is" : "\(heldCount) entries from Siri or a widget are"
      return "\(entries) waiting. Subscribe and they'll be saved straight away."
    }
    if type != nil { return "Subscribe and this entry saves straight away. Nothing you've typed is lost." }
    return "You've had a feel for Scrunch. Subscribe to keep logging everything."
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(title)
        .font(.app(.displayBold, 28, relativeTo: .largeTitle))
        .foregroundStyle(C.ink)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
      Subtitle(subtitle)
      VStack(alignment: .leading, spacing: 8) {
        ForEach(Subscription.includes, id: \.self) { item in
          PaywallBullet(text: item)
        }
      }
      Text(Subscription.alwaysFree)
        .font(.app(.medium, 14))
        .foregroundStyle(C.tealDark)
        .fixedSize(horizontal: false, vertical: true)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(C.tealSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      Text(Subscription.renewalTerms)
        .font(.app(.body, 12, relativeTo: .caption))
        .foregroundStyle(C.muted)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 24)
    .padding(.top, 24)
  }
}

private struct PaywallBullet: View {
  let text: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: "checkmark.circle.fill").foregroundStyle(C.teal).accessibilityHidden(true)
      Text(text)
        .font(.app(.medium, 15))
        .foregroundStyle(C.ink)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

/// Ask and patterns: open during the free entries, then a calm explanation and a way in.
struct SubscriptionGate<Content: View>: View {
  let babyId: BabyID
  let feature: Subscription.Feature
  @ViewBuilder var content: Content

  @Environment(LogGate.self) private var gate
  @State private var showPaywall = false

  var body: some View {
    Group {
      if gate.featureOpen(babyId) {
        content
      } else {
        ScreenScaffold {
          ScreenTitle(feature.title)
          Subtitle(feature.pitch)
          Text(Subscription.alwaysFree)
            .font(.app(.medium, 15))
            .foregroundStyle(C.tealDark)
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(C.tealSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
          PrimaryButton(label: "See subscription options") { showPaywall = true }
        }
      }
    }
    // Outside the branches, so the sheet survives the switch to `content` after a purchase.
    .sheet(isPresented: $showPaywall) { PaywallView(feature: feature) }
  }
}

/// The Subscription row in Profile: status or free entries left, Manage and Restore.
struct SubscriptionRow: View {
  let babyId: BabyID?

  @Environment(Entitlements.self) private var entitlements
  @Environment(LogGate.self) private var gate
  @State private var showPaywall = false
  @State private var showManage = false
  @State private var restoring = false
  @State private var alert: FormAlert?

  private var freeLeft: String {
    guard let babyId, let allowance = gate.allowances[babyId] else {
      return "\(FreeAllowance.limit) free entries of each log type. Sleep is always free."
    }
    if allowance.unlocked { return "Unlocked by a subscription from someone you share this baby with." }
    let used = LogType.allCases.filter { allowance.used($0) > 0 }
    guard !used.isEmpty else { return "\(FreeAllowance.limit) of each log type. Sleep is always free." }
    let left = used.map { "\($0.plural) \(FreeAllowance.remaining(used: allowance.used($0)))" }.joined(separator: ", ")
    return "Out of \(FreeAllowance.limit) each: \(left). Everything else has all \(FreeAllowance.limit). Sleep is always free."
  }

  var body: some View {
    let status = entitlements.status
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Subscription").font(.app(.medium, 13)).foregroundStyle(C.muted)
        Text(status?.planName ?? "Free entries left").font(.app(.bold, 17)).foregroundStyle(C.ink)
        Text(status?.summary() ?? freeLeft)
          .font(.app(.body, 14))
          .foregroundStyle(C.muted)
          .fixedSize(horizontal: false, vertical: true)
      }
      .accessibilityElement(children: .combine)

      if !gate.held.isEmpty {
        Text(gate.held.count == 1 ? "1 entry is waiting to save." : "\(gate.held.count) entries are waiting to save.")
          .font(.app(.medium, 14))
          .foregroundStyle(C.ink)
        Button("Discard waiting entries", role: .destructive) { gate.discardHeld() }
          .font(.app(.bold, 15))
          .frame(minHeight: 44)
      }

      if status == nil {
        PrimaryButton(label: "See subscription options") { showPaywall = true }
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
    .sheet(isPresented: $showPaywall, onDismiss: { gate.paywallClosed() }) { PaywallView(heldCount: gate.held.count) }
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
      gate.paywallClosed()
      alert = entitlements.subscribed
        ? FormAlert(title: "Subscription restored", message: "Thanks for supporting Scrunch.")
        : FormAlert(title: "Nothing to restore", message: "We couldn't find a Scrunch subscription for this Apple ID.")
    } catch StoreKitError.userCancelled {
      return
    } catch {
      alert = FormAlert(title: "Could not restore", message: UserMessage.from(error, fallback: "Check your connection and try again."))
    }
  }
}
