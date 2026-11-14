import Foundation

// String helpers from app/(app)/(tabs)/index.tsx.

public enum HomeCopy {
  /// "Now", "25m", "2h", "1h 5m"
  public static func countdown(_ ms: Double) -> String {
    if ms <= 0 { return "Now" }
    let total = Int((ms / 60_000).rounded(.up))
    let hours = total / 60
    let minutes = total % 60
    if hours == 0 { return "\(minutes)m" }
    if minutes == 0 { return "\(hours)h" }
    return "\(hours)h \(minutes)m"
  }

  /// "13.4h", "12h"
  public static func hours(_ hours: Double) -> String {
    "\(jsNumber(jsRound(hours * 10) / 10))h"
  }

  public static func lastFeedKind(_ event: Event) -> String {
    if event.feedKind == .bottle { return "Bottle" }
    switch event.side {
    case .left: return "Left"
    case .right: return "Right"
    case .both: return "Both"
    case nil: return "Feed"
    }
  }

  public static func lastNappyKind(_ event: Event) -> String {
    switch event.nappy {
    case .both: return "Wee + poo"
    case .poo: return "Poo"
    case .wee: return "Wee"
    case nil: return "Nappy"
    }
  }

  public static func lastFeedStrip(_ event: Event?, now: EpochMs) -> String {
    guard let event else { return "No feeds yet" }
    return "\(lastFeedKind(event)) · \(Format.relative(event.loggedAt, now: now))"
  }

  public static func lastNappyStrip(_ event: Event?, now: EpochMs) -> String {
    guard let event else { return "No nappies yet" }
    return "\(lastNappyKind(event)) · \(Format.relative(event.loggedAt, now: now))"
  }

  public static func lastSleepStrip(_ event: Event?, now: EpochMs) -> String {
    guard let event else { return "No sleep yet" }
    return durationPrefix(event) + Format.relative(event.loggedAt, now: now)
  }

  public static func lastTummyStrip(_ event: Event?, now: EpochMs) -> String {
    guard let event else { return "No tummy yet" }
    return durationPrefix(event) + Format.relative(event.loggedAt, now: now)
  }

  static func durationPrefix(_ event: Event) -> String {
    guard let minutes = event.durationMinutes, minutes > 0 else { return "" }
    return "\(jsNumber(minutes)) min · "
  }

  /// "Next nap" / "Bedtime" label above the countdown.
  public static func countdownLabel(_ countdown: SleepCountdown) -> String {
    countdown.kind == .night && countdown.inMs > 0 ? "Bedtime" : "Next nap"
  }

  // MARK: Freshness

  public enum Freshness: Equatable, Sendable {
    case noLogs
    case fresh
    case stale(lastLoggedAt: EpochMs)
  }

  /// Babies feed and need changing every few hours, so a longer silence means the
  /// day's numbers (and any nap prediction) are out of date.
  public static let staleAfterMs: Double = 12 * 3_600_000

  /// When the most recent log finished (a sleep counts from when it ended).
  public static func lastLoggedAt(_ events: [Event?]) -> EpochMs? {
    events.compactMap { $0.map { $0.loggedAt + max(0, $0.durationMinutes ?? 0) * minuteMs } }.max()
  }

  public static func freshness(lastLoggedAt: EpochMs?, now: EpochMs) -> Freshness {
    guard let lastLoggedAt else { return .noLogs }
    return now - lastLoggedAt > staleAfterMs ? .stale(lastLoggedAt: lastLoggedAt) : .fresh
  }

  /// "Nothing logged for 14 hours" or "Nothing logged since Fri 7 Nov".
  public static func staleTitle(lastLoggedAt: EpochMs, now: EpochMs, calendar: Calendar = .current) -> String {
    let hours = Int(max(0, now - lastLoggedAt) / 3_600_000)
    if hours < 48 { return "Nothing logged for \(hours) hours" }
    return "Nothing logged since \(LoggedAt.shortDay(lastLoggedAt, now: now, calendar: calendar))"
  }

  public static let staleBody = "Today’s numbers and nap times will be off until you log again. Start with whatever’s happening now."

  public static func welcomeTitle(babyName: String) -> String {
    "Let’s log \(babyName)’s first feed"
  }

  public static func welcomeBody(babyName: String) -> String {
    "Log feeds, sleeps and nappies as they happen. After a day or so, \(babyName)’s rhythm and nap times show up here."
  }

  public static let targetsFootnote = "Rings fill towards a typical day at this age."
}

/// The home-screen widget payload (all strings preformatted, like RN's `BabyGlanceProps`).
public struct GlanceSnapshot: Codable, Equatable, Sendable {
  public var babyName: String
  public var nextNap: String
  public var lastFeed: String
  public var lastNappy: String
  public var sleepToday: String

  public init(babyName: String, nextNap: String, lastFeed: String, lastNappy: String, sleepToday: String) {
    self.babyName = babyName
    self.nextNap = nextNap
    self.lastFeed = lastFeed
    self.lastNappy = lastNappy
    self.sleepToday = sleepToday
  }

  public static let placeholder = GlanceSnapshot(
    babyName: "Scrunch",
    nextNap: "Watch cues",
    lastFeed: "No feeds yet",
    lastNappy: "No nappies yet",
    sleepToday: "0h today"
  )

  /// UserDefaults key in the shared app group.
  public static let storageKey = "glance-snapshot-v1"

  public static func make(
    babyName: String,
    asleep: Bool,
    napAt: EpochMs?,
    lastFeed: Event?,
    lastNappy: Event?,
    sleepMinutesToday: Double,
    now: EpochMs,
    calendar: Calendar = .current
  ) -> GlanceSnapshot {
    let nextNap: String
    if asleep {
      nextNap = "Asleep"
    } else if let napAt {
      nextNap = napAt > now ? "Often ready ~\(Clock.h12(napAt, calendar: calendar))" : "Offer a nap"
    } else {
      nextNap = "Watch cues"
    }
    return GlanceSnapshot(
      babyName: babyName,
      nextNap: nextNap,
      lastFeed: lastFeed.map { "\(HomeCopy.lastFeedKind($0)) · \(Clock.h12($0.loggedAt, calendar: calendar))" } ?? "No feeds yet",
      lastNappy: lastNappy.map { "\(HomeCopy.lastNappyKind($0)) · \(Clock.h12($0.loggedAt, calendar: calendar))" } ?? "No nappies yet",
      sleepToday: "\(HomeCopy.hours(sleepMinutesToday / 60)) today"
    )
  }
}
