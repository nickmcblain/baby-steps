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
        .adaptiveDetents([.height(AddLogSheet.detentHeight), .large])
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
  @Environment(\.dynamicTypeSize) private var typeSize

  private let height: CGFloat = 56

  /// Like the system tab bar: at accessibility sizes the dock shows icons only and
  /// press-and-hold brings up the Large Content Viewer.
  private var showsLabels: Bool { !typeSize.isAccessibilitySize }

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
          .foregroundStyle(C.onAccent)
          .frame(width: height, height: height)
          .background(C.teal, in: Circle())
          .cardShadow(opacity: 0.2)
      }
      .buttonStyle(PressScale())
      .accessibilityLabel("Log")
      .accessibilityHint("Opens the add log sheet")
      .accessibilityInputLabels(["Log", "Add", "Plus", "Add log"])
      .accessibilityShowsLargeContentViewer { Label("Log", systemImage: "plus") }
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .padding(.bottom, 2)
  }

  private func item(_ tab: Tab, _ label: LocalizedStringKey, _ symbol: String) -> some View {
    let active = selected == tab
    return Button {
      selected = tab
    } label: {
      VStack(spacing: 3) {
        Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
        if showsLabels {
          Text(label).font(.app(.medium, 11, relativeTo: .caption))
        }
      }
      .foregroundStyle(active ? C.ink : C.muted)
      .frame(maxWidth: .infinity, minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressScale())
    .accessibilityLabel(label)
    .accessibilityAddTraits(active ? [.isSelected, .isButton] : .isButton)
    .accessibilityShowsLargeContentViewer { Label(label, systemImage: symbol) }
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
        .accessibilityHidden(true)
        if showsLabels {
          Text("Profile").font(.app(.medium, 11, relativeTo: .caption))
            .foregroundStyle(active ? C.ink : C.muted)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressScale())
    .accessibilityLabel("Profile")
    .accessibilityAddTraits(active ? [.isSelected, .isButton] : .isButton)
    .accessibilityShowsLargeContentViewer { Label("Profile", systemImage: "person.crop.circle") }
  }
}
