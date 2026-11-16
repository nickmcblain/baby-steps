import ClerkKit
import ScrunchCore
import SwiftUI

/// Port of app/(app)/_layout.tsx + StoreUser: waits for Convex auth, stores the user once,
/// then hosts the tabs and every pushed screen.
struct SignedInRoot: View {
  @Environment(ConvexService.self) private var convex
  @Environment(AppRouter.self) private var router
  @Environment(ActiveBabyStore.self) private var activeBaby
  @Environment(\.scenePhase) private var scenePhase
  @Environment(SaveFeedback.self) private var saveFeedback
  @State private var babies = Live<[Baby]>()
  @Environment(Entitlements.self) private var entitlements
  @Environment(LogGate.self) private var gate
  @State private var storedUser = false
  @State private var slowConnect = false
  @State private var undo = UndoCenter()

  var body: some View {
    @Bindable var router = router
    Group {
      // With a last-known copy on disk the tabs render straight away; queries wait for auth.
      if convex.auth == .signedIn || convex.hasLastKnownState {
        NavigationStack(path: $router.path) {
          MainTabView()
            .navigationDestination(for: Route.self) { route in
              destination(route)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { SyncBanner() }
        .saveFeedbackHost()
        .task { await babies.bind(API.babies.list(), convex, cacheKey: API.babies.list().key) }
        .onChange(of: babies.value) { _, list in saveFeedback.remember(list ?? []) }
        .overlay(alignment: .bottom) {
          // Over the dock, so it never covers the quick-log buttons.
          UndoToastView().padding(.bottom, 6)
        }
        .animation(.snappy(duration: 0.25), value: undo.toast?.id)
        .environment(undo)
        .onChange(of: scenePhase) { _, phase in
          if phase == .background { undo.settle() }
          if phase == .active {
            gate.presentHeldIfNeeded()
            Task { await PendingLogSender.shared.send() }
          }
        }
        .sheet(item: Bindable(gate).paywall, onDismiss: { gate.paywallClosed() }) { request in
          PaywallView(type: request.type, heldCount: request.heldCount)
        }
        .task {
          gate.undo = undo
          gate.clearSheets = { [router] in
            defer { router.addLogOpen = false }
            return router.addLogOpen
          }
          PendingLogSender.shared.onHeld = { [gate] in gate.presentHeldIfNeeded() }
          gate.presentHeldIfNeeded()
        }
        // With a last-known copy the tabs show before auth; these need Convex to answer.
        .task(id: convex.auth == .signedIn) {
          guard convex.auth == .signedIn else { return }
          await entitlements.connect(convex)
        }
        .task(id: convex.auth == .signedIn) {
          guard convex.auth == .signedIn else { return }
          await gate.bind(convex)
        }
        .onChange(of: entitlements.subscribed) { gate.mirror() }
        .onChange(of: router.requestedBabyId) { _, id in
          guard let id else { return }
          activeBaby.select(id)
          router.requestedBabyId = nil
        }
        .task(id: convex.auth == .signedIn) {
          guard convex.auth == .signedIn else { return }
          await PendingLogSender.shared.send()
          guard !storedUser else { return }
          // Auth may still be settling; reactive queries recover either way.
          if (try? await convex.mutation(API.users.store())) != nil { storedUser = true }
        }
        .onChange(of: babies.value, initial: true) { syncIntentBabies() }
        .onChange(of: activeBaby.babyId) { syncIntentBabies() }
      } else {
        connecting
      }
    }
  }

  private func syncIntentBabies() {
    guard let list = babies.value else { return }
    PendingLogSender.publish(babies: list, activeId: activeBaby.babyId)
  }

  private var connecting: some View {
    VStack(spacing: 16) {
      if slowConnect {
        Text("Can't reach Scrunch").font(.app(.bold, 17)).foregroundStyle(C.ink)
        Text("Check your connection and try again.").font(.app(.body, 15)).foregroundStyle(C.muted)
      } else {
        ProgressView().tint(C.teal)
        Text("Connecting…").font(.app(.body, 15)).foregroundStyle(C.muted)
      }
      if slowConnect {
        VStack(spacing: 10) {
          Button("Try again") {
            Task { await convex.retry(manual: true) }
          }
          .font(.app(.bold, 16))
          Button("Sign out") {
            Task { try? await Clerk.shared.auth.signOut() }
          }
          .font(.app(.medium, 15))
          .foregroundStyle(C.muted)
        }
        .padding(.top, 8)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(C.bg.ignoresSafeArea())
    .task {
      try? await Task.sleep(for: .seconds(8))
      slowConnect = true
    }
  }

  @ViewBuilder
  private func destination(_ route: Route) -> some View {
    switch route {
    case .newBaby:
      NewBabyView()
    case .baby(let id, let screen):
      BabyDestination(babyId: id, screen: screen)
    }
  }
}

struct BabyDestination: View {
  let babyId: BabyID
  let screen: BabyScreen

  var body: some View {
    switch screen {
    case .edit: EditBabyView(babyId: babyId)
    case .customEvent: CustomEventView(babyId: babyId)
    case .feedTimer: FeedTimerView(babyId: babyId, kind: .feed)
    case .pumpTimer: FeedTimerView(babyId: babyId, kind: .pump)
    case .feedManual(let handoff): FeedManualView(babyId: babyId, handoff: handoff)
    case .pumpManual(let handoff): PumpManualView(babyId: babyId, handoff: handoff)
    case .sleepTimer: DurationTimerView(babyId: babyId, kind: .sleep)
    case .tummyTimer: DurationTimerView(babyId: babyId, kind: .tummy)
    case .sleepManual(let handoff): DurationManualView(babyId: babyId, kind: .sleep, handoff: handoff)
    case .tummyManual(let handoff): DurationManualView(babyId: babyId, kind: .tummy, handoff: handoff)
    case .feedPatterns: GatedPatterns(babyId: babyId, kind: .feed)
    case .sleepPatterns: GatedPatterns(babyId: babyId, kind: .sleep)
    case .tummyPatterns: GatedPatterns(babyId: babyId, kind: .tummy)
    case .nappyPatterns: GatedPatterns(babyId: babyId, kind: .nappy)
    case .nappy: NappyView(babyId: babyId, potty: false)
    case .potty: NappyView(babyId: babyId, potty: true)
    case .medicine: MedicineView(babyId: babyId)
    case .activity: ActivityLogView(babyId: babyId)
    case .clothing: ClothingView(babyId: babyId)
    case .weight: GrowthLogView(babyId: babyId, metric: .weight)
    case .height: GrowthLogView(babyId: babyId, metric: .length)
    case .ask(let question, let thread):
      SubscriptionGate(babyId: babyId, feature: .ask) { AskView(babyId: babyId, initialQuestion: question, threadId: thread) }
    case .askHistory: SubscriptionGate(babyId: babyId, feature: .ask) { AskHistoryView(babyId: babyId) }
    }
  }
}
