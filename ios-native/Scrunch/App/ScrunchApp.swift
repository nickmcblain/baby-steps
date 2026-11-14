import ClerkKit
import ClerkKitUI
import SwiftUI
import UserNotifications

@main
struct ScrunchApp: App {
  @State private var convex: ConvexService?
  @State private var router = AppRouter()
  @State private var activeBaby = ActiveBabyStore()

  init() {
    UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
    if AppConfig.isComplete {
      Clerk.configure(publishableKey: AppConfig.clerkPublishableKey)
      _convex = State(initialValue: ConvexService(deploymentUrl: AppConfig.convexURL))
    }
  }

  var body: some Scene {
    WindowGroup {
      Group {
        if let convex {
          RootView()
            .environment(convex)
            .environment(router)
            .environment(activeBaby)
            .environment(TimerStore.shared)
            .prefetchClerkImages()
            // Outermost, so ClerkKitUI modifiers like prefetchClerkImages() can see it too.
            .environment(Clerk.shared)
        } else {
          MissingConfigView()
        }
      }
      .preferredColorScheme(.light)
      .tint(C.teal)
      .onOpenURL { router.handle(url: $0) }
    }
  }
}

struct RootView: View {
  @Environment(Clerk.self) private var clerk

  var body: some View {
    if !clerk.isLoaded {
      LoadingView()
    } else if clerk.session == nil {
      SignInView()
    } else {
      SignedInRoot()
    }
  }
}

struct MissingConfigView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Almost there")
        .font(.app(.displayBold, 28))
        .foregroundStyle(C.ink)
      Text("CLERK_PUBLISHABLE_KEY or CONVEX_URL was not set for this build. Copy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig, fill it in, and build again.")
        .font(.app(.body, 16))
        .foregroundStyle(C.muted)
        .lineSpacing(6)
    }
    .padding(28)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(C.bg.ignoresSafeArea())
  }
}
