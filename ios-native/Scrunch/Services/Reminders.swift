import Foundation
import ScrunchCore
import UserNotifications

/// Local notifications. Decisions and copy come from `ScrunchCore.ReminderPlans`;
/// this file only talks to `UNUserNotificationCenter`. Identifiers match the RN build,
/// so anything it scheduled is replaced rather than duplicated.
@MainActor
enum Reminders {
  private static var center: UNUserNotificationCenter { .current() }
  private static var napScheduledFor: [BabyID: EpochMs] = [:]
  private static var digestScheduledFor: Set<String> = []

  static func isAllowed() async -> Bool {
    let status = await center.notificationSettings().authorizationStatus
    return status == .authorized || status == .provisional || status == .ephemeral
  }

  /// Asks once; later calls just report the current state.
  static func ensurePermission() async -> Bool {
    if await isAllowed() { return true }
    let granted = try? await center.requestAuthorization(options: [.alert, .sound])
    return granted ?? false
  }

  // MARK: Feed

  /// Schedule (or refresh) the next feed check-in. `quiet` skips the permission prompt.
  static func refreshFeed(baby: Baby, lastFeedAt: EpochMs?, quiet: Bool = true) async {
    let allowed = quiet ? await isAllowed() : await ensurePermission()
    let sleeping = TimerStore.shared.session?.isAsleep(babyId: baby.id) ?? false
    switch ReminderPlans.feed(baby: baby, lastFeedAt: lastFeedAt, sleepTimerRunning: sleeping, now: Date().epochMs) {
    case .cancel, .suppressedForSleep:
      cancel(ReminderPlans.feedIdentifier(baby.id))
    case .schedule(let plan):
      guard allowed else { return }
      cancel(plan.identifier)
      await schedule(plan)
    }
  }

  // MARK: Nap

  static func refreshNap(babyId: BabyID, babyName: String, napAt: EpochMs?, asleep: Bool) async {
    guard let plan = ReminderPlans.nap(babyId: babyId, babyName: babyName, napAt: napAt, asleep: asleep, now: Date().epochMs) else {
      cancel(ReminderPlans.napIdentifier(babyId))
      napScheduledFor[babyId] = nil
      return
    }
    if napScheduledFor[babyId] == napAt { return }
    guard await isAllowed() else { return }
    cancel(plan.identifier)
    await schedule(plan)
    napScheduledFor[babyId] = napAt
  }

  // MARK: Medicine

  /// Returns false when nothing was scheduled (no permission).
  @discardableResult
  static func scheduleMedicine(babyId: BabyID, babyName: String, name: String, dose: String?, hours: Int?) async -> Bool {
    guard let plan = ReminderPlans.medicine(babyId: babyId, babyName: babyName, name: name, dose: dose, hours: hours, now: Date().epochMs) else {
      return false
    }
    guard await ensurePermission() else { return false }
    cancel(plan.identifier)
    await schedule(plan)
    return true
  }

  // MARK: Weekly digest

  static func ensureWeeklyDigest(babyId: BabyID, babyName: String) async {
    let key = "\(babyId):\(babyName)"
    guard !digestScheduledFor.contains(key), await isAllowed() else { return }
    let id = ReminderPlans.digestIdentifier(babyId)
    cancel(id)
    let content = UNMutableNotificationContent()
    content.title = ReminderPlans.digestTitle(babyName)
    content.body = ReminderPlans.digestBody
    content.userInfo = ["babyId": babyId, "kind": "weekly-digest"]
    var when = DateComponents()
    when.weekday = ReminderPlans.digestWeekday
    when.hour = ReminderPlans.digestHour
    when.minute = 0
    let request = UNNotificationRequest(
      identifier: id,
      content: content,
      trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
    )
    try? await center.add(request)
    digestScheduledFor.insert(key)
  }

  // MARK: Plumbing

  private static func schedule(_ plan: NotificationPlan) async {
    let content = UNMutableNotificationContent()
    content.title = plan.title
    content.body = plan.body
    content.sound = .default
    content.userInfo = ["babyId": plan.babyId, "kind": plan.kind]
    let interval = max(1, (plan.fireAt - Date().epochMs) / 1000)
    let request = UNNotificationRequest(
      identifier: plan.identifier,
      content: content,
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
    )
    try? await center.add(request)
  }

  private static func cancel(_ identifier: String) {
    center.removePendingNotificationRequests(withIdentifiers: [identifier])
  }
}

/// Show banners while the app is open, like the RN `setNotificationHandler`.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
  static let shared = NotificationPresenter()

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .list, .sound]
  }
}
