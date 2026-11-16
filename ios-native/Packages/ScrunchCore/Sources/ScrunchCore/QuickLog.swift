import Foundation

/// One-tap logging from the Home tab: defaults, copy, and after-the-fact time fixes.
public enum QuickLog {
  /// The chips offered on running timers and just-saved logs.
  public static let shiftMinutes = [5, 15]

  public enum Nappy: String, CaseIterable, Sendable {
    case wet, dirty, both

    public var kind: NappyKind {
      switch self {
      case .wet: .wee
      case .dirty: .poo
      case .both: .both
      }
    }

    public var label: String {
      switch self {
      case .wet: String(localized: "Wet", bundle: .module)
      case .dirty: String(localized: "Dirty", bundle: .module)
      case .both: String(localized: "Both", bundle: .module)
      }
    }

    /// Same defaults as the nappy form.
    public var weeSize: NappySize? { self == .dirty ? nil : .medium }
    public var pooSize: NappySize? { self == .wet ? nil : .medium }

    public var loggedCopy: String {
      switch self {
      case .wet: String(localized: "Wet nappy logged", bundle: .module)
      case .dirty: String(localized: "Dirty nappy logged", bundle: .module)
      case .both: String(localized: "Wet and dirty nappy logged", bundle: .module)
      }
    }
  }

  /// The breast to offer next: the other side from the last breastfeed, else left.
  public static func suggestedSide(lastFeed: Event?) -> TimerSide {
    guard let lastFeed, lastFeed.feedKind != .bottle else { return .left }
    switch lastFeed.side {
    case .left: return .right
    case .right: return .left
    case .both, nil: return .left
    }
  }

  /// "Last side: Left, 2h 5m ago"; nil when there is no breastfeed to go on.
  public static func lastSideLine(lastFeed: Event?, now: EpochMs) -> String? {
    guard let lastFeed, lastFeed.feedKind != .bottle, let side = lastFeed.side else { return nil }
    let word = switch side {
    case .left: String(localized: "Left", bundle: .module)
    case .right: String(localized: "Right", bundle: .module)
    case .both: String(localized: "Both", bundle: .module)
    }
    return String(localized: "Last side: \(word), \(Format.relative(lastFeed.loggedAt, now: now))", bundle: .module)
  }

  /// "Wet nappy logged · 14:32"
  public static func savedCopy(_ title: String, loggedAt: EpochMs, calendar: Calendar = .current) -> String {
    "\(title) · \(Clock.time(loggedAt, calendar: calendar))"
  }

  /// "Started 14:32"
  public static func startedCopy(_ session: TimerSession, calendar: Calendar = .current) -> String {
    String(localized: "Started \(Clock.time(session.sessionStartedAt, calendar: calendar))", bundle: .module)
  }

  /// A saved log moved earlier by `minutes`, snapped like every other save.
  public static func shifted(_ loggedAt: EpochMs, minutes: Int) -> EpochMs {
    LoggedAt.snapToMinute(loggedAt - Double(minutes) * minuteMs)
  }

  /// "Feeding · Left", "Asleep", "Tummy time", "Pumping · Right"
  public static func runningTitle(_ session: TimerSession) -> String {
    let side = sideSuffix(session)
    switch session.kind {
    case .sleep: return session.isRunning ? String(localized: "Asleep", bundle: .module) : String(localized: "Sleep paused", bundle: .module)
    case .tummy: return session.isRunning ? String(localized: "Tummy time", bundle: .module) : String(localized: "Tummy time paused", bundle: .module)
    case .feed: return session.isRunning ? String(localized: "Feeding\(side)", bundle: .module) : String(localized: "Feed paused", bundle: .module)
    case .pump: return session.isRunning ? String(localized: "Pumping\(side)", bundle: .module) : String(localized: "Pump paused", bundle: .module)
    }
  }

  /// Toast copy after a one-tap start.
  public static func startedToast(_ session: TimerSession) -> String {
    switch session.kind {
    case .sleep: return String(localized: "Sleep timer started", bundle: .module)
    case .tummy: return String(localized: "Tummy time started", bundle: .module)
    case .feed: return String(localized: "Feed started\(sideSuffix(session))", bundle: .module)
    case .pump: return String(localized: "Pump started", bundle: .module)
    }
  }

  private static func sideSuffix(_ session: TimerSession) -> String {
    session.activeSide.map { $0 == .left ? String(localized: " · Left", bundle: .module) : String(localized: " · Right", bundle: .module) } ?? ""
  }
}

extension TimerSession {
  /// "I forgot to press start": move the start earlier and count those minutes. On a
  /// two-sided timer they go to the running side, else the side used most, else left.
  public mutating func shiftStart(byMinutes minutes: Int) {
    guard minutes > 0 else { return }
    let delta = Double(minutes) * minuteMs
    sessionStartedAt -= delta
    if kind.isSided {
      let side = activeSide ?? ((rightBaseMs ?? 0) > (leftBaseMs ?? 0) ? .right : .left)
      if side == .left {
        leftBaseMs = (leftBaseMs ?? 0) + delta
      } else {
        rightBaseMs = (rightBaseMs ?? 0) + delta
      }
    } else {
      sleepBaseMs = (sleepBaseMs ?? 0) + delta
    }
  }

  /// A fresh timer that is already running: a breastfeed on `side`, or a sleep / tummy clock.
  public static func started(kind: TimerKind, side: TimerSide = .left, babyId: BabyID, babyName: String?, now: EpochMs) -> TimerSession {
    var session = TimerSession(kind: kind, babyId: babyId, babyName: babyName, now: now)
    if kind.isSided {
      session.tapSide(side, now: now)
    } else {
      session.toggle(now: now)
    }
    return session
  }
}
