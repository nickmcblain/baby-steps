import Foundation

// Decisions and copy from lib/feedReminders.ts, napReminders.ts, medicineReminders.ts and
// digestReminder.ts. The app turns these into UNNotificationRequests with the same
// identifiers, so the native app replaces anything the RN build had scheduled.

public struct NotificationPlan: Equatable, Sendable {
  public var identifier: String
  public var title: String
  public var body: String
  /// `userInfo["kind"]`
  public var kind: String
  public var babyId: BabyID
  public var fireAt: EpochMs
}

public enum ReminderPlans {
  // MARK: Feed

  public enum FeedOutcome: Equatable, Sendable {
    /// No last feed: cancel any pending reminder.
    case cancel
    /// A running sleep timer and guidance says let them sleep: cancel, remember the due time.
    case suppressedForSleep(dueAt: EpochMs)
    case schedule(NotificationPlan)
  }

  public static func feedIdentifier(_ babyId: BabyID) -> String { "feed-reminder:\(babyId)" }

  public static func feed(
    baby: Baby,
    lastFeedAt: EpochMs?,
    sleepTimerRunning: Bool,
    now: EpochMs
  ) -> FeedOutcome {
    guard let lastFeedAt, lastFeedAt.isFinite else { return .cancel }
    let window = FeedWindows.window(for: baby, now: now)
    let dueAt = FeedWindows.nextFeedDueAt(lastFeedAt: lastFeedAt, window: window)
    if sleepTimerRunning && !window.shouldWakeForFeeds {
      return .suppressedForSleep(dueAt: dueAt)
    }
    // If already due, nudge in 60s so it doesn't fire mid-save.
    let fireAt = max(dueAt, now + 60_000)
    return .schedule(NotificationPlan(
      identifier: feedIdentifier(baby.id),
      title: String(localized: "\(baby.name) · feed check", bundle: .module),
      body: window.shouldWakeForFeeds
        ? String(localized: "Around \(window.label) since the last feed — time for a gentle check.", bundle: .module)
        : String(localized: "Around \(window.label) since the last feed — offer if they're stirring.", bundle: .module),
      kind: "feed-reminder",
      babyId: baby.id,
      fireAt: fireAt
    ))
  }

  // MARK: Nap

  static let napLeadMs: Double = 10 * 60_000

  public static func napIdentifier(_ babyId: BabyID) -> String { "nap-reminder:\(babyId)" }

  /// Nil means cancel. Never prompts for permission (feed reminders own that flow).
  public static func nap(
    babyId: BabyID,
    babyName: String,
    napAt: EpochMs?,
    asleep: Bool,
    now: EpochMs,
    calendar: Calendar = .current
  ) -> NotificationPlan? {
    guard !asleep, let napAt, napAt - napLeadMs > now else { return nil }
    return NotificationPlan(
      identifier: napIdentifier(babyId),
      title: String(localized: "\(babyName) · nap window soon", bundle: .module),
      body: String(localized: "Often ready around \(Clock.time(napAt, calendar: calendar)). Watch for cues.", bundle: .module),
      kind: "nap-reminder",
      babyId: babyId,
      fireAt: napAt - napLeadMs
    )
  }

  // MARK: Medicine

  public static let medicineReminderHours: [Int?] = [4, 6, 8, nil]

  static func slug(_ name: String) -> String {
    let lowered = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let dashed = lowered.split(whereSeparator: \.isWhitespace).joined(separator: "-")
    return String(dashed.prefix(40))
  }

  public static func medicineIdentifier(babyId: BabyID, name: String) -> String {
    "medicine-reminder:\(babyId):\(slug(name))"
  }

  public static func medicine(
    babyId: BabyID,
    babyName: String,
    name: String,
    dose: String?,
    hours: Int?,
    now: EpochMs
  ) -> NotificationPlan? {
    guard let hours, hours > 0 else { return nil }
    let doseBit = dose.flatMap { $0.isEmpty ? nil : " · \($0)" } ?? ""
    return NotificationPlan(
      identifier: medicineIdentifier(babyId: babyId, name: name),
      title: "\(babyName) · \(name)",
      body: String(localized: "Next dose due\(doseBit).", bundle: .module),
      kind: "medicine-reminder",
      babyId: babyId,
      fireAt: now + Double(hours) * hourMs
    )
  }

  // MARK: Weekly digest (Sunday 18:00, repeating)

  public static func digestIdentifier(_ babyId: BabyID) -> String { "digest:\(babyId)" }

  public static func digestTitle(_ babyName: String) -> String { String(localized: "Your week with \(babyName) is ready", bundle: .module) }

  public static let digestBody = String(localized: "Open Scrunch to see how sleep and feeds changed.", bundle: .module)

  /// `DateComponents.weekday` for Sunday, and the hour/minute.
  public static let digestWeekday = 1
  public static let digestHour = 18
}
