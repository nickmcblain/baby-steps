import Foundation
import ScrunchCore
import WidgetKit

/// Where intents and widget buttons put logs. Compiled into the app and the widget extension.
enum QuickLogStore {
  static var queue: PendingLogQueue { PendingLogQueue(defaults: GlanceStore.defaults) }
  static var babies: SharedBabies { SharedBabies.load(from: GlanceStore.defaults) }

  /// Queue the log, show it on the widgets, and send it now if this is the app's process.
  @MainActor
  static func record(_ log: PendingLog) async {
    queue.enqueue(log)
    if log.babyId == babies.active?.id, let snapshot = GlanceStore.load() {
      GlanceStore.save(snapshot.applying(log))
    }
    #if !WIDGET_EXTENSION
    await PendingLogSender.shared.send()
    #endif
    WidgetCenter.shared.reloadAllTimelines()
  }
}
