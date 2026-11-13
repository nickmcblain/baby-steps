import ActivityKit
import Foundation
import ScrunchCore

/// Live Activity for sleep / feed / tummy / pump timers (RN `BabyTimerActivity`).
/// Compiled into both the app and the widget extension.
struct BabyTimerAttributes: ActivityAttributes {
  typealias ContentState = TimerActivityContent

  var babyId: String
  var kind: String

  /// `babysteps://baby/{id}/{kind}/timer`
  var deepLink: URL? { URL(string: "babysteps://baby/\(babyId)/\(kind)/timer") }
}
