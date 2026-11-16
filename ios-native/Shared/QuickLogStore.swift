import Foundation
import ScrunchCore
import WidgetKit

/// Where intents and widget buttons put logs. Compiled into the app and the widget extension.
enum QuickLogStore {
  static var queue: PendingLogQueue { PendingLogQueue(defaults: GlanceStore.defaults) }
  static var held: PendingLogQueue { PendingLogQueue(defaults: GlanceStore.defaults, key: PendingLogQueue.heldKey) }
  static var babies: SharedBabies { SharedBabies.load(from: GlanceStore.defaults) }

  enum Outcome: Equatable {
    case queued
    /// Past the free allowance: kept until the parent subscribes in the app.
    case held(LogType?)
  }

  /// Queue the log, show it on the widgets, and send it now if this is the app's process.
  /// Past the free allowance the log is held instead, never dropped.
  @MainActor
  @discardableResult
  static func record(_ log: PendingLog) async -> Outcome {
    let allowance = SharedAllowance.load(from: GlanceStore.defaults)
    guard allowance.canLog(log.log, babyId: log.babyId) else {
      held.enqueue(log)
      WidgetCenter.shared.reloadAllTimelines()
      return .held(FreeAllowance.type(for: log.log))
    }
    allowance.counting(log.log, babyId: log.babyId).save(to: GlanceStore.defaults)
    queue.enqueue(log)
    if log.babyId == babies.active?.id, let snapshot = GlanceStore.load() {
      GlanceStore.save(snapshot.applying(log))
    }
    #if !WIDGET_EXTENSION
    await PendingLogSender.shared.send()
    #endif
    WidgetCenter.shared.reloadAllTimelines()
    return .queued
  }
}
