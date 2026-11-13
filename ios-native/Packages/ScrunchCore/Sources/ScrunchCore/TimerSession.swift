import Foundation

// Port of the state maths in lib/liveTimer.ts and the timer screens.
// One timer runs at a time across the app (persisted so the Live Activity, the home
// "asleep" state and feed-reminder suppression can read it).

public enum TimerKind: String, Codable, Sendable {
  case sleep, feed, tummy, pump

  /// Duration timers (one clock) vs two-sided timers (left / right).
  public var isSided: Bool { self == .feed || self == .pump }
}

public enum TimerSide: String, Codable, Sendable {
  case left, right
}

/// Same JSON shape as the RN `PersistedTimer`.
public struct TimerSession: Codable, Equatable, Sendable {
  public var kind: TimerKind
  public var babyId: BabyID
  public var babyName: String?
  /// Wall clock when the session first started.
  public var sessionStartedAt: EpochMs
  /// Sleep / tummy: accumulated ms while paused.
  public var sleepBaseMs: Double?
  /// Sleep / tummy: when the current run segment started; nil when paused.
  public var sleepTickOrigin: EpochMs?
  /// Feed / pump.
  public var leftBaseMs: Double?
  public var rightBaseMs: Double?
  public var activeSide: TimerSide?
  public var feedTickOrigin: EpochMs?

  public init(kind: TimerKind, babyId: BabyID, babyName: String?, now: EpochMs) {
    self.kind = kind
    self.babyId = babyId
    self.babyName = babyName
    self.sessionStartedAt = now
    if kind.isSided {
      leftBaseMs = 0
      rightBaseMs = 0
    } else {
      sleepBaseMs = 0
    }
  }

  public var isRunning: Bool {
    kind.isSided ? (activeSide != nil && feedTickOrigin != nil) : sleepTickOrigin != nil
  }

  /// A running sleep timer — the home screen shows "Asleep" and may pause feed nudges.
  public func isAsleep(babyId: BabyID) -> Bool {
    kind == .sleep && self.babyId == babyId && sleepTickOrigin != nil
  }

  // MARK: Elapsed

  public func elapsed(now: EpochMs) -> Double {
    if kind.isSided { return sideElapsed(.left, now: now) + sideElapsed(.right, now: now) }
    let base = sleepBaseMs ?? 0
    if let origin = sleepTickOrigin { return base + (now - origin) }
    return base
  }

  public func sideElapsed(_ side: TimerSide, now: EpochMs) -> Double {
    let base = side == .left ? (leftBaseMs ?? 0) : (rightBaseMs ?? 0)
    if activeSide == side, let origin = feedTickOrigin { return base + (now - origin) }
    return base
  }

  // MARK: Duration timers (sleep / tummy)

  /// Start or pause. Returns the new running state.
  @discardableResult
  public mutating func toggle(now: EpochMs) -> Bool {
    if let origin = sleepTickOrigin {
      sleepBaseMs = (sleepBaseMs ?? 0) + (now - origin)
      sleepTickOrigin = nil
      return false
    }
    sleepTickOrigin = now
    return true
  }

  public mutating func pause(now: EpochMs) {
    if kind.isSided {
      pauseActiveSide(now: now)
    } else if sleepTickOrigin != nil {
      toggle(now: now)
    }
  }

  // MARK: Two-sided timers (feed / pump)

  /// Tap a side: starts it, switches to it, or pauses it if it was already running.
  public mutating func tapSide(_ side: TimerSide, now: EpochMs) {
    let wasActive = activeSide
    if wasActive != nil { pauseActiveSide(now: now) }
    if wasActive == side { return }
    activeSide = side
    feedTickOrigin = now
  }

  mutating func pauseActiveSide(now: EpochMs) {
    guard let side = activeSide, let origin = feedTickOrigin else { return }
    let delta = now - origin
    if side == .left {
      leftBaseMs = (leftBaseMs ?? 0) + delta
    } else {
      rightBaseMs = (rightBaseMs ?? 0) + delta
    }
    activeSide = nil
    feedTickOrigin = nil
  }

  // MARK: Finishing

  /// Whole minutes for a stretch: 0 under 5 seconds, otherwise at least 1.
  public static func minutes(fromMs ms: Double) -> Int {
    if ms < 5_000 { return 0 }
    return max(1, Int(jsRound(ms / 60_000)))
  }

  public func canFinish(now: EpochMs) -> Bool {
    if kind.isSided {
      return sideElapsed(.left, now: now) >= 5_000 || sideElapsed(.right, now: now) >= 5_000
    }
    return elapsed(now: now) >= 5_000
  }

  /// What the manual screen is pre-filled with after "Done".
  public struct Handoff: Equatable, Sendable {
    public var minutes: Int
    public var side: Side?
    public var startedAt: EpochMs
    public var leftMinutes: Int?
    public var rightMinutes: Int?

    /// The feed note the RN app pre-fills when both sides were used.
    public var bothSidesNote: String? {
      guard let leftMinutes, let rightMinutes else { return nil }
      return "Left \(leftMinutes) min · Right \(rightMinutes) min"
    }
  }

  /// Call after `pause(now:)`. Nil when there is nothing worth saving.
  public func handoff() -> Handoff? {
    let startedAt = LoggedAt.snapToMinute(sessionStartedAt)
    if kind.isSided {
      let left = Self.minutes(fromMs: leftBaseMs ?? 0)
      let right = Self.minutes(fromMs: rightBaseMs ?? 0)
      let total = left + right
      guard total > 0 else { return nil }
      let side: Side = left > 0 && right > 0 ? .both : (right > 0 ? .right : .left)
      return Handoff(
        minutes: total,
        side: side,
        startedAt: startedAt,
        leftMinutes: left > 0 ? left : nil,
        rightMinutes: right > 0 ? right : nil
      )
    }
    let minutes = Self.minutes(fromMs: sleepBaseMs ?? 0)
    guard minutes > 0 else { return nil }
    return Handoff(minutes: minutes, side: nil, startedAt: startedAt, leftMinutes: nil, rightMinutes: nil)
  }

  // MARK: Live Activity

  /// The Live Activity's content for the current state.
  public func liveActivityContent(now: EpochMs) -> TimerActivityContent {
    let running = isRunning
    let elapsedMs: Double
    let side: TimerSide?
    if kind.isSided {
      if running, let active = activeSide {
        elapsedMs = sideElapsed(active, now: now)
        side = active
      } else {
        elapsedMs = (leftBaseMs ?? 0) + (rightBaseMs ?? 0)
        side = (rightBaseMs ?? 0) > (leftBaseMs ?? 0) ? .right : .left
      }
    } else {
      elapsedMs = elapsed(now: now)
      side = nil
    }
    return TimerActivityContent(kind: kind, side: side, babyName: babyName, running: running, elapsedMs: max(0, elapsedMs), now: now)
  }

  /// `babysteps://baby/{id}/{kind}/timer`
  public var deepLink: String { "babysteps://baby/\(babyId)/\(kind.rawValue)/timer" }
}

/// Mirrors the RN `BabyTimerProps` passed to the Live Activity.
public struct TimerActivityContent: Codable, Equatable, Hashable, Sendable {
  public enum Style: String, Codable, Sendable { case sleep, feed, tummy }

  public var style: Style
  /// "Sleep", "Tummy time", "Feed · Left", "Pump · Right"
  public var title: String
  /// Baby name, may be empty.
  public var subtitle: String
  public var running: Bool
  /// Effective start for the count-up clock (now − elapsed).
  public var startEpochMs: EpochMs
  /// Upper bound for the count-up interval (start + 24h).
  public var endEpochMs: EpochMs
  /// Static clock shown while paused, e.g. "12:34".
  public var pausedLabel: String

  public init(kind: TimerKind, side: TimerSide?, babyName: String?, running: Bool, elapsedMs: Double, now: EpochMs) {
    switch kind {
    case .sleep:
      style = .sleep
      title = "Sleep"
    case .tummy:
      style = .tummy
      title = "Tummy time"
    case .pump:
      style = .feed
      title = side == .right ? "Pump · Right" : side == .left ? "Pump · Left" : "Pump"
    case .feed:
      style = .feed
      title = side == .right ? "Feed · Right" : side == .left ? "Feed · Left" : "Feed"
    }
    subtitle = babyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    self.running = running
    startEpochMs = now - elapsedMs
    endEpochMs = startEpochMs + dayMs
    pausedLabel = TimerClock.format(elapsedMs)
  }
}

public enum TimerClock {
  /// "H:MM:SS" or "MM:SS".
  public static func format(_ ms: Double) -> String {
    let totalSec = Int(max(0, (ms / 1000).rounded(.down)))
    let hours = totalSec / 3600
    let minutes = (totalSec % 3600) / 60
    let seconds = totalSec % 60
    if hours > 0 { return "\(hours):\(Clock.pad2(minutes)):\(Clock.pad2(seconds))" }
    return "\(Clock.pad2(minutes)):\(Clock.pad2(seconds))"
  }
}
