import Foundation

extension QuickLog.Nappy: Codable {}

// Logs written outside the app (App Intents, Siri, interactive widgets, Live Activity
// buttons). The widget extension has no Clerk session, so every log is queued in the
// shared app group and the app sends it to Convex: straight away when the intent runs in
// the app's process, otherwise the next time the app opens.

public enum LogEntry: Codable, Equatable, Sendable {
  case feed(FeedKind, side: Side?, minutes: Double?, amountMl: Double?, milk: Milk?)
  case nappy(QuickLog.Nappy)
  case potty(QuickLog.Nappy)
  case sleep(minutes: Double)
  case tummy(minutes: Double)
  case pump(Side, minutes: Double, amountMl: Double?)
  case weight(grams: Double)
  case height(cm: Double)
  case medicine(title: String)
  case activity(title: String, minutes: Double?)
  case custom(title: String)

  /// Sentence-case summary for Siri and Shortcuts, e.g. "Wet nappy", "Bottle · 120 ml".
  public var summary: String { summary(format: .current) }

  public func summary(format: DisplayFormat) -> String {
    switch self {
    case .feed(.bottle, _, _, let ml, _):
      return ml.map { String(localized: "Bottle · \(format.volume($0))", bundle: .module) } ?? String(localized: "Bottle feed", bundle: .module)
    case .feed(.breast, let side, let minutes, _, _):
      let label = switch side {
      case .left: String(localized: "Feed · Left", bundle: .module)
      case .right: String(localized: "Feed · Right", bundle: .module)
      case .both: String(localized: "Feed · Both", bundle: .module)
      case nil: String(localized: "Feed", bundle: .module)
      }
      return minutes.map { "\(label) · \(Self.minutes($0))" } ?? label
    case .nappy(let nappy): return Self.nappyLabel(nappy)
    case .potty(let nappy): return String(localized: "Potty · \(Self.pottyLabel(nappy))", bundle: .module)
    case .sleep(let minutes): return String(localized: "Sleep · \(Self.minutes(minutes))", bundle: .module)
    case .tummy(let minutes): return String(localized: "Tummy time · \(Self.minutes(minutes))", bundle: .module)
    case .pump(let side, let minutes, let ml):
      let base = String(localized: "Pump · \(Self.sideLabel(side)) · \(Self.minutes(minutes))", bundle: .module)
      return ml.map { "\(base) · \(format.volume($0))" } ?? base
    case .weight(let grams):
      let value = format.weightUnit == .lb ? format.weight(grams) : "\(Self.number(grams / 1000, places: 2)) kg"
      return String(localized: "Weight · \(value)", bundle: .module)
    case .height(let cm): return String(localized: "Height · \(format.length(cm))", bundle: .module)
    case .medicine(let title): return String(localized: "Medicine · \(title)", bundle: .module)
    case .activity(let title, _): return String(localized: "Activity · \(title)", bundle: .module)
    case .custom(let title): return title
    }
  }

  static func nappyLabel(_ nappy: QuickLog.Nappy) -> String {
    switch nappy {
    case .wet: String(localized: "Wet nappy", bundle: .module)
    case .dirty: String(localized: "Dirty nappy", bundle: .module)
    case .both: String(localized: "Wet and dirty nappy", bundle: .module)
    }
  }

  static func pottyLabel(_ nappy: QuickLog.Nappy) -> String {
    switch nappy {
    case .wet: String(localized: "Wee", bundle: .module)
    case .dirty: String(localized: "Poo", bundle: .module)
    case .both: String(localized: "Wee + poo", bundle: .module)
    }
  }

  static func sideLabel(_ side: Side) -> String {
    switch side {
    case .left: String(localized: "Left", bundle: .module)
    case .right: String(localized: "Right", bundle: .module)
    case .both: String(localized: "Both", bundle: .module)
    }
  }

  static func minutes(_ value: Double) -> String {
    String(localized: "\(number(value)) min", bundle: .module)
  }

  static func number(_ value: Double, places: Int = 0) -> String {
    if places == 0 || value.rounded() == value { return String(Int(value.rounded())) }
    return String(format: "%.\(places)f", value)
  }
}

public struct PendingLog: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var babyId: BabyID
  public var loggedAt: EpochMs
  public var log: LogEntry
  public var note: String?

  public init(id: String = UUID().uuidString, babyId: BabyID, loggedAt: EpochMs, log: LogEntry, note: String? = nil) {
    self.id = id
    self.babyId = babyId
    self.loggedAt = loggedAt
    self.log = log
    self.note = note
  }

  public var call: ConvexCall<EventID> {
    switch log {
    case .feed(let kind, let side, let minutes, let ml, let milk):
      return API.events.logFeed(
        babyId: babyId,
        loggedAt: loggedAt,
        feedKind: kind,
        side: kind == .breast ? side : nil,
        durationMinutes: minutes,
        amountMl: kind == .bottle ? (ml ?? 0) : nil,
        milk: kind == .bottle ? milk : nil,
        note: note
      )
    case .nappy(let nappy):
      return API.events.logNappy(babyId: babyId, loggedAt: loggedAt, nappy: nappy.kind, weeSize: nappy.weeSize, pooSize: nappy.pooSize, note: note)
    case .potty(let nappy): return API.events.logPotty(babyId: babyId, loggedAt: loggedAt, nappy: nappy.kind, note: note)
    case .sleep(let minutes): return API.events.logSleep(babyId: babyId, loggedAt: loggedAt, durationMinutes: minutes, note: note)
    case .tummy(let minutes): return API.events.logTummy(babyId: babyId, loggedAt: loggedAt, durationMinutes: minutes, note: note)
    case .pump(let side, let minutes, let ml):
      return API.events.logPump(babyId: babyId, loggedAt: loggedAt, side: side, durationMinutes: minutes, amountMl: ml, note: note)
    case .weight(let grams): return API.events.logWeight(babyId: babyId, loggedAt: loggedAt, weightGrams: grams, note: note)
    case .height(let cm): return API.events.logHeight(babyId: babyId, loggedAt: loggedAt, heightCm: cm, note: note)
    case .medicine(let title): return API.events.logMedicine(babyId: babyId, loggedAt: loggedAt, title: title, note: note)
    case .activity(let title, let minutes):
      return API.events.logActivity(babyId: babyId, loggedAt: loggedAt, title: title, durationMinutes: minutes, note: note)
    case .custom(let title): return API.events.logCustom(babyId: babyId, loggedAt: loggedAt, title: title, note: note)
    }
  }
}

/// FIFO of logs waiting for the app to send them. Several processes share it, so every
/// operation re-reads the stored list rather than caching it.
public struct PendingLogQueue {
  public static let storageKey = "pending-logs-v1"
  /// Logs past the free allowance, kept until the parent subscribes or discards them.
  public static let heldKey = "held-logs-v1"

  private let defaults: UserDefaults
  private let key: String

  public init(defaults: UserDefaults, key: String = Self.storageKey) {
    self.defaults = defaults
    self.key = key
  }

  public var all: [PendingLog] {
    guard let data = defaults.data(forKey: key) else { return [] }
    return (try? JSONDecoder().decode([PendingLog].self, from: data)) ?? []
  }

  public func enqueue(_ log: PendingLog) {
    write(all + [log])
  }

  public func remove(id: String) {
    write(all.filter { $0.id != id })
  }

  private func write(_ logs: [PendingLog]) {
    if logs.isEmpty {
      defaults.removeObject(forKey: key)
    } else if let data = try? JSONEncoder().encode(logs) {
      defaults.set(data, forKey: key)
    }
  }
}

/// The babies the signed-in user can log for, mirrored into the app group so intents and
/// widgets can resolve "the active baby" without a Convex connection.
public struct SharedBabies: Codable, Equatable, Sendable {
  public struct Ref: Codable, Equatable, Hashable, Sendable {
    public var id: BabyID
    public var name: String

    public init(id: BabyID, name: String) {
      self.id = id
      self.name = name
    }
  }

  public static let storageKey = "shared-babies-v1"

  public var babies: [Ref]
  public var activeId: BabyID?

  public init(babies: [Ref], activeId: BabyID?) {
    self.babies = babies
    self.activeId = activeId
  }

  /// The active baby, falling back to the first one when it has gone.
  public var active: Ref? {
    babies.first { $0.id == activeId } ?? babies.first
  }

  public static func load(from defaults: UserDefaults) -> SharedBabies {
    guard let data = defaults.data(forKey: storageKey),
          let value = try? JSONDecoder().decode(SharedBabies.self, from: data) else {
      return SharedBabies(babies: [], activeId: nil)
    }
    return value
  }

  /// Returns false when nothing changed.
  @discardableResult
  public func save(to defaults: UserDefaults) -> Bool {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    guard let data = try? encoder.encode(self) else { return false }
    if defaults.data(forKey: Self.storageKey) == data { return false }
    defaults.set(data, forKey: Self.storageKey)
    return true
  }
}

extension TimerSession {
  /// What stopping the timer from the Live Activity saves. Call after `pause(now:)`.
  /// Nil when the timer ran for under five seconds.
  public func finishedLog() -> PendingLog? {
    guard let handoff = handoff() else { return nil }
    let minutes = Double(handoff.minutes)
    let log: LogEntry = switch kind {
    case .sleep: .sleep(minutes: minutes)
    case .tummy: .tummy(minutes: minutes)
    case .feed: .feed(.breast, side: handoff.side, minutes: minutes, amountMl: nil, milk: nil)
    case .pump: .pump(handoff.side ?? .left, minutes: minutes, amountMl: nil)
    }
    let note = kind == .feed ? handoff.bothSidesNote : nil
    return PendingLog(babyId: babyId, loggedAt: handoff.startedAt, log: log, note: note)
  }
}

extension GlanceSnapshot {
  /// Shows a log on the widget straight away, before the app has synced it.
  public func applying(_ pending: PendingLog, calendar: Calendar = .current) -> GlanceSnapshot {
    var next = self
    let time = Clock.time(pending.loggedAt, calendar: calendar)
    switch pending.log {
    case .feed(.bottle, _, _, _, _):
      next.lastFeed = String(localized: "Bottle · \(time)", bundle: .module)
    case .feed(.breast, let side, _, _, _):
      let label = side.map(LogEntry.sideLabel) ?? String(localized: "Feed", bundle: .module)
      next.lastFeed = "\(label) · \(time)"
    case .nappy(let nappy):
      next.lastNappy = "\(LogEntry.pottyLabel(nappy)) · \(time)"
    default:
      break
    }
    return next
  }
}
