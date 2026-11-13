import ClerkKit
import ScrunchCore
import SwiftUI

/// Port of app/(app)/(tabs)/_layout.tsx + CalTabBar: four tabs in a floating pill dock,
/// with a teal "+" that opens the add-log sheet.
struct MainTabView: View {
  @Environment(AppRouter.self) private var router
  @Environment(ActiveBabyStore.self) private var activeBaby

  var body: some View {
    @Bindable var router = router
    ZStack(alignment: .bottom) {
      Group {
        switch router.tab {
        case .home: HomeView()
        case .timeline: TimelineTab()
        case .kids: KidsView()
        case .profile: ProfileView()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      FloatingDock(selected: $router.tab) { router.addLogOpen = true }
    }
    .background(C.bg.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .sheet(isPresented: $router.addLogOpen) {
      AddLogSheet(babyId: activeBaby.babyId)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(C.bg)
    }
  }
}

struct FloatingDock: View {
  @Binding var selected: Tab
  let onAdd: () -> Void

  @Environment(Clerk.self) private var clerk

  private let height: CGFloat = 56

  var body: some View {
    HStack(spacing: 10) {
      HStack(spacing: 0) {
        item(.home, "Home", "house.fill")
        item(.timeline, "Timeline", "list.bullet.rectangle.fill")
        item(.kids, "Kids", "figure.and.child.holdinghands")
        profileItem
      }
      .frame(height: height)
      .background(C.card, in: Capsule())
      .cardShadow()

      Button(action: onAdd) {
        Image(systemName: "plus")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: height, height: height)
          .background(C.teal, in: Circle())
          .cardShadow(opacity: 0.2)
      }
      .buttonStyle(PressScale())
      .accessibilityLabel("Log")
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .padding(.bottom, 2)
  }

  private func item(_ tab: Tab, _ label: String, _ symbol: String) -> some View {
    let active = selected == tab
    return Button {
      selected = tab
    } label: {
      VStack(spacing: 3) {
        Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
        Text(label).font(.app(.medium, 11, relativeTo: .caption2))
      }
      .foregroundStyle(active ? C.ink : C.muted)
      .frame(maxWidth: .infinity, minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressScale())
    .accessibilityLabel(label)
    .accessibilityAddTraits(active ? [.isSelected, .isButton] : .isButton)
  }

  private var profileItem: some View {
    let active = selected == .profile
    return Button {
      selected = .profile
    } label: {
      VStack(spacing: 3) {
        AsyncImage(url: clerk.user.flatMap { URL(string: $0.imageUrl) }) { image in
          image.resizable().scaledToFill()
        } placeholder: {
          C.line
        }
        .frame(width: 22, height: 22)
        .clipShape(Circle())
        .overlay(Circle().stroke(C.ink, lineWidth: active ? 1.5 : 0))
        Text("Profile").font(.app(.medium, 11, relativeTo: .caption2))
          .foregroundStyle(active ? C.ink : C.muted)
      }
      .frame(maxWidth: .infinity, minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressScale())
    .accessibilityLabel("Profile")
    .accessibilityAddTraits(active ? [.isSelected, .isButton] : .isButton)
  }
}
