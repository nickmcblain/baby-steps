import Foundation
import Observation
import ScrunchCore
import WidgetKit

/// Which baby the Home tab and the add-log sheet act on (RN `lib/activeBaby.ts`).
@MainActor
@Observable
final class ActiveBabyStore {
  private static let key = "baby-steps.activeBabyId"

  private(set) var babyId: BabyID? = UserDefaults.standard.string(forKey: key)

  func select(_ id: BabyID) {
    babyId = id
    UserDefaults.standard.set(id, forKey: Self.key)
  }
}

enum Tab: Hashable { case home, timeline, kids, profile }

/// Every pushed screen. Baby screens carry the baby id, like the RN `/baby/[id]/…` routes.
enum Route: Hashable {
  case newBaby
  case baby(BabyID, BabyScreen)
}

enum BabyScreen: Hashable {
  case home, edit, timeline, customEvent
  case feedTimer, feedManual(TimerSession.Handoff?), feedPatterns
  case sleepTimer, sleepManual(TimerSession.Handoff?), sleepPatterns
  case tummyTimer, tummyManual(TimerSession.Handoff?), tummyPatterns
  case pumpTimer, pumpManual(TimerSession.Handoff?)
  case nappy, nappyPatterns, potty
  case medicine, activity, clothing
  case weight, height
  case ask(question: String? = nil, thread: ThreadID? = nil), askHistory

  /// `babysteps://baby/{id}/{kind}/timer`
  init?(timerKind: String) {
    switch timerKind {
    case "sleep": self = .sleepTimer
    case "feed": self = .feedTimer
    case "tummy": self = .tummyTimer
    case "pump": self = .pumpTimer
    default: return nil
    }
  }
}

@MainActor
@Observable
final class AppRouter {
  var tab: Tab = .home
  var path: [Route] = []
  var addLogOpen = false

  func push(_ babyId: BabyID, _ screen: BabyScreen) {
    path.append(.baby(babyId, screen))
  }

  /// Replace the top screen (timer → manual entry, like RN `router.replace`).
  func replaceTop(_ babyId: BabyID, _ screen: BabyScreen) {
    if !path.isEmpty { path.removeLast() }
    path.append(.baby(babyId, screen))
  }

  /// RN `router.dismissTo("/baby/{id}")`: pop back to that baby's home, or replace the
  /// current screen with it when it isn't on the stack.
  func dismissToBabyHome(_ babyId: BabyID) {
    if let index = path.lastIndex(of: .baby(babyId, .home)) {
      path.removeSubrange((index + 1)...)
    } else {
      replaceTop(babyId, .home)
    }
  }

  func popToRoot(tab: Tab? = nil) {
    path.removeAll()
    if let tab { self.tab = tab }
  }

  func handle(url: URL) {
    // babysteps://baby/{id}/{kind}/timer → host "baby", path "/{id}/{kind}/timer"
    guard url.scheme == "babysteps", url.host == "baby" else { return }
    let parts = url.pathComponents.filter { $0 != "/" }
    guard parts.count >= 2 else { return }
    let babyId = parts[0]
    if parts.count >= 3, parts[2] == "timer", let screen = BabyScreen(timerKind: parts[1]) {
      path = [.baby(babyId, screen)]
    } else {
      path = [.baby(babyId, .home)]
    }
  }
}

enum WidgetSync {
  static func push(_ snapshot: GlanceSnapshot) {
    if GlanceStore.save(snapshot) {
      WidgetCenter.shared.reloadTimelines(ofKind: GlanceStore.widgetKind)
    }
  }
}
