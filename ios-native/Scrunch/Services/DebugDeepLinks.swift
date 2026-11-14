#if DEBUG
import Foundation
import ScrunchCore

/// DEBUG-only deep links for screenshot and UX-review runs. Not compiled into release builds.
///
///   babysteps://debug/tab/{home|timeline|kids|profile}
///   babysteps://debug/sheet/addlog
///   babysteps://debug/new-baby
///   babysteps://debug/baby/{screen}[/{babyId}]   (defaults to the active baby)
///
/// Drive with `xcrun simctl openurl booted <url>`.
extension AppRouter {
  /// Returns true when the URL was a debug link (handled or ignored), false to fall through.
  func handleDebug(url: URL, activeBabyId: BabyID?) -> Bool {
    guard url.scheme == "babysteps", url.host == "debug" else { return false }
    let parts = url.pathComponents.filter { $0 != "/" }
    addLogOpen = false
    switch parts.first {
    case "tab":
      let tabs: [String: Tab] = ["home": .home, "timeline": .timeline, "kids": .kids, "profile": .profile]
      if parts.count > 1, let tab = tabs[parts[1]] { popToRoot(tab: tab) }
    case "sheet":
      if parts.count > 1, parts[1] == "addlog" {
        popToRoot()
        addLogOpen = true
      }
    case "new-baby":
      path = [.newBaby]
    case "baby":
      guard parts.count > 1, let screen = BabyScreen(debugName: parts[1]),
            let id = parts.count > 2 ? parts[2] : activeBabyId
      else { break }
      path = [.baby(id, screen)]
    default:
      break
    }
    return true
  }
}

extension BabyScreen {
  init?(debugName: String) {
    switch debugName {
    case "home": self = .home
    case "edit": self = .edit
    case "timeline": self = .timeline
    case "customEvent": self = .customEvent
    case "feedTimer": self = .feedTimer
    case "feedManual": self = .feedManual(nil)
    case "feedPatterns": self = .feedPatterns
    case "sleepTimer": self = .sleepTimer
    case "sleepManual": self = .sleepManual(nil)
    case "sleepPatterns": self = .sleepPatterns
    case "tummyTimer": self = .tummyTimer
    case "tummyManual": self = .tummyManual(nil)
    case "tummyPatterns": self = .tummyPatterns
    case "pumpTimer": self = .pumpTimer
    case "pumpManual": self = .pumpManual(nil)
    case "nappy": self = .nappy
    case "nappyPatterns": self = .nappyPatterns
    case "potty": self = .potty
    case "medicine": self = .medicine
    case "activity": self = .activity
    case "clothing": self = .clothing
    case "weight": self = .weight
    case "height": self = .height
    case "ask": self = .ask()
    case "askHistory": self = .askHistory
    default: return nil
    }
  }
}
#endif
