import SwiftUI
import WidgetKit

@main
struct ScrunchWidgetsBundle: WidgetBundle {
  var body: some Widget {
    BabyGlanceWidget()
    QuickLogWidget()
    BabyTimerLiveActivity()
    if #available(iOS 18.0, *) {
      StartFeedControl()
      StartNapControl()
    }
  }
}
