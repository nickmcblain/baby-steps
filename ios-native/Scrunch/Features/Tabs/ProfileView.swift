import ClerkKit
import ClerkKitUI
import ScrunchCore
import SwiftUI

/// Port of app/(app)/(tabs)/profile.tsx.
struct ProfileView: View {
  @Environment(ConvexService.self) private var convex
  @Environment(Clerk.self) private var clerk
  @State private var user = Live<ScrunchCore.User?>()
  @AppStorage(WeightPreference.storageKey) private var weightPreference = WeightPreference.automatic

  private var email: String {
    user.value??.email ?? clerk.user?.primaryEmailAddress?.emailAddress ?? "—"
  }

  var body: some View {
    ScreenScaffold(showsBack: false, clearDock: true) {
      HStack {
        ScreenTitle("Profile")
        Spacer()
        UserButton()
      }
      Card {
        row("Email", email)
        Rectangle().fill(C.line).frame(height: 1)
        row("Subscription", "Not subscribed")
      }
      Card {
        FieldLabel("Show weights in")
        Picker("Show weights in", selection: weightUnit) {
          Text("kg").tag(WeightUnit.kg)
          Text("lb & oz").tag(WeightUnit.lb)
        }
        .pickerStyle(.segmented)
      }
    }
    .task { await user.bind(API.users.current(), convex) }
  }

  /// Starts on the region's unit; picking one pins it.
  private var weightUnit: Binding<WeightUnit> {
    Binding(
      get: { DisplayFormat(weightPreference: weightPreference).weightUnit },
      set: { weightPreference = $0 == .lb ? .lbOz : .kg }
    )
  }

  private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label).font(.app(.medium, 13)).foregroundStyle(C.muted)
      Text(value).font(.app(.bold, 17)).foregroundStyle(C.ink)
    }
    .accessibilityElement(children: .combine)
  }
}
