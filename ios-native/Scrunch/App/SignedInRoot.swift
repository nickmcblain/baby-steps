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
  @State private var storedUser = false
  @State private var slowConnect = false
  @State private var undo = UndoCenter()

  var body: some View {
    @Bindable var router = router
    Group {
      switch convex.auth {
      case .signedIn:
        NavigationStack(path: $router.path) {
          MainTabView()
            .navigationDestination(for: Route.self) { route in
              destination(route)
            }
        }
        .saveFeedbackHost()
        .task { await babies.bind(API.babies.list(), convex) }
        .onChange(of: babies.value) { _, list in saveFeedback.remember(list ?? []) }
        .overlay(alignment: .bottom) {
          // Over the dock, so it never covers the quick-log buttons.
          UndoToastView().padding(.bottom, 6)
        }
        .animation(.snappy(duration: 0.25), value: undo.toast?.id)
        .environment(undo)
        .onChange(of: scenePhase) { _, phase in
          if phase == .background { undo.settle() }
        }
        .onChange(of: router.requestedBabyId) { _, id in
          guard let id else { return }
          activeBaby.select(id)
          router.requestedBabyId = nil
        }
        .task {
          guard !storedUser else { return }
          // Auth may still be settling; reactive queries recover either way.
          if (try? await convex.mutation(API.users.store())) != nil { storedUser = true }
        }
      case .loading, .signedOut:
        connecting
      }
    }
  }

  private var connecting: some View {
    VStack(spacing: 16) {
      ProgressView().tint(C.teal)
      Text("Connecting…").font(.app(.body, 15)).foregroundStyle(C.muted)
      if slowConnect {
        VStack(spacing: 10) {
          Button("Try again") {
            Task { _ = await convex.client.loginFromCache() }
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
    case .feedPatterns: PatternsView(babyId: babyId, kind: .feed)
    case .sleepPatterns: PatternsView(babyId: babyId, kind: .sleep)
    case .tummyPatterns: PatternsView(babyId: babyId, kind: .tummy)
    case .nappyPatterns: PatternsView(babyId: babyId, kind: .nappy)
    case .nappy: NappyView(babyId: babyId, potty: false)
    case .potty: NappyView(babyId: babyId, potty: true)
    case .medicine: MedicineView(babyId: babyId)
    case .activity: ActivityLogView(babyId: babyId)
    case .clothing: ClothingView(babyId: babyId)
    case .weight: GrowthLogView(babyId: babyId, metric: .weight)
    case .height: GrowthLogView(babyId: babyId, metric: .length)
    case .ask(let question, let thread): AskView(babyId: babyId, initialQuestion: question, threadId: thread)
    case .askHistory: AskHistoryView(babyId: babyId)
    }
  }
}
