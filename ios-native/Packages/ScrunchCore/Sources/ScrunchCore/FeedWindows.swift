import Foundation

// Port of lib/feedWindows.ts. Rough UK-style feed windows — cues still matter; not medical advice.

public struct FeedWindow: Equatable, Sendable {
  /// Suggested gap after a feed before a gentle check-in.
  public var intervalMs: Double
  /// e.g. "about 2.5 hours".
  public var label: String
  /// Younger / lighter babies are often still woken for feeds. When false, an active
  /// sleep timer suppresses feed reminders.
  public var shouldWakeForFeeds: Bool
  public var reason: String
}

public enum FeedWindows {
  public static func window(
    dateOfBirth: EpochMs,
    weightGrams: Double,
    feedingMode: FeedingMode?,
    now: EpochMs
  ) -> FeedWindow {
    let days = max(0, ((now - dateOfBirth) / dayMs).rounded(.down))
    let bottleBias = feedingMode == .bottle || feedingMode == .mixed ? 0.5 * hourMs : 0

    let intervalMs: Double
    let label: String
    if days < 28 {
      intervalMs = 2.5 * hourMs + bottleBias
      label = bottleBias > 0 ? "about 3 hours" : "about 2.5 hours"
    } else if days < 84 {
      intervalMs = 3 * hourMs + bottleBias
      label = bottleBias > 0 ? "about 3.5 hours" : "about 3 hours"
    } else if days < 180 {
      intervalMs = 3.5 * hourMs + bottleBias * 0.5
      label = "about 3.5 hours"
    } else {
      intervalMs = 4 * hourMs
      label = "about 4 hours"
    }

    // Err on waking: under ~8 weeks or under ~5 kg — still check / wake.
    let shouldWake = days < 56 || weightGrams < 5000
    let reason: String
    if shouldWake {
      reason = days < 56
        ? "Under 8 weeks — feed check-ins stay on even if they're asleep."
        : "Under 5 kg — feed check-ins stay on even if they're asleep."
    } else {
      reason = "At this age and weight, an active sleep timer pauses feed reminders so you can leave them sleeping."
    }
    return FeedWindow(intervalMs: intervalMs, label: label, shouldWakeForFeeds: shouldWake, reason: reason)
  }

  public static func window(for baby: Baby, now: EpochMs) -> FeedWindow {
    window(dateOfBirth: baby.dateOfBirth, weightGrams: baby.weightGrams, feedingMode: baby.feedingMode, now: now)
  }

  public static func nextFeedDueAt(lastFeedAt: EpochMs, window: FeedWindow) -> EpochMs {
    lastFeedAt + window.intervalMs
  }

  /// The end of a feed (start + duration) — what the RN app passes as `lastFeedAt`.
  public static func feedEndedAt(_ event: Event) -> EpochMs {
    event.loggedAt + (event.durationMinutes ?? 0) * minuteMs
  }
}
