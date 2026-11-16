import ClerkKit
import ClerkKitUI
import SwiftUI
import UserNotifications

@main
struct ScrunchApp: App {
  @State private var convex: ConvexService?
  @State private var router = AppRouter()
  @State private var activeBaby = ActiveBabyStore()
  @State private var saveFeedback = SaveFeedback()
  @State private var entitlements: Entitlements
  @State private var gate: LogGate

  init() {
    LaunchMetrics.appStarted()
    UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
    let entitlements = Entitlements()
    _entitlements = State(initialValue: entitlements)
    _gate = State(initialValue: LogGate(entitlements: entitlements))
    if AppConfig.isComplete {
      Clerk.configure(publishableKey: AppConfig.clerkPublishableKey)
      let convex = ConvexService(deploymentUrl: AppConfig.convexURL)
      PendingLogSender.shared.convex = convex
      _convex = State(initialValue: convex)
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
            .environment(saveFeedback)
            .environment(TimerStore.shared)
            .environment(entitlements)
            .environment(gate)
            .prefetchClerkImages()
            // Outermost, so ClerkKitUI modifiers like prefetchClerkImages() can see it too.
            .environment(Clerk.shared)
        } else {
          MissingConfigView()
        }
      }
      .tint(C.teal)
      .task { entitlements.start() }
      #if DEBUG
      .task { router.applyLaunchDebugURL(activeBabyId: activeBaby.babyId) }
      .debugPaywall(entitlements)
      #endif
      .onOpenURL { url in
        #if DEBUG
        if router.handleDebug(url: url, activeBabyId: activeBaby.babyId) { return }
        #endif
        router.handle(url: url)
      }
    }
  }
}

struct RootView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(ConvexService.self) private var convex

  var body: some View {
    Group {
      if !clerk.isLoaded {
        SplashLoadingView()
      } else if clerk.session == nil {
        SignInView()
      } else {
        SignedInRoot()
      }
    }
    .onChange(of: clerk.session == nil) { _, signedOut in
      if signedOut { convex.cache.clear() }
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
