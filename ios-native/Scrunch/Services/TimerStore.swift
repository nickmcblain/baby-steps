import ActivityKit
import Foundation
import Observation
import ScrunchCore

/// The one running timer (sleep / feed / tummy / pump), persisted so it survives relaunch,
/// mirrored to a Live Activity. Port of lib/liveTimer.ts.
@MainActor
@Observable
final class TimerStore {
  static let shared = TimerStore()

  /// Same key name as the RN AsyncStorage entry.
  private static let storageKey = "baby-steps:live-timer-v1"
  private static var defaults: UserDefaults { UserDefaults(suiteName: GlanceStore.appGroup) ?? .standard }

  private(set) var session: TimerSession?

  @ObservationIgnored private var activity: Activity<BabyTimerAttributes>?

  private init() {
    if let data = Self.defaults.data(forKey: Self.storageKey) {
      session = try? JSONDecoder().decode(TimerSession.self, from: data)
    }
    activity = Activity<BabyTimerAttributes>.activities.first
  }

  func session(for kind: TimerKind, babyId: BabyID) -> TimerSession? {
    guard let session, session.kind == kind, session.babyId == babyId else { return nil }
    return session
  }

  /// Save and push the Live Activity. Returns an error message when the Live Activity
  /// could not start (the timer itself still runs).
  @discardableResult
  func update(_ next: TimerSession) async -> String? {
    session = next
    if let data = try? JSONEncoder().encode(next) {
      Self.defaults.set(data, forKey: Self.storageKey)
    }
    return await syncActivity(next)
  }

  func stop() async {
    session = nil
    Self.defaults.removeObject(forKey: Self.storageKey)
    for running in Activity<BabyTimerAttributes>.activities {
      await running.end(nil, dismissalPolicy: .immediate)
    }
    activity = nil
  }

  private func syncActivity(_ session: TimerSession) async -> String? {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      return "Live Activities are turned off for Scrunch in Settings."
    }
    let state = session.liveActivityContent(now: Date().epochMs)
    let content = ActivityContent(state: state, staleDate: nil)
    if let activity, activity.activityState == .active,
       activity.attributes.babyId == session.babyId, activity.attributes.kind == session.kind.rawValue {
      await activity.update(content)
      return nil
    }
    for stale in Activity<BabyTimerAttributes>.activities {
      await stale.end(nil, dismissalPolicy: .immediate)
    }
    do {
      activity = try Activity.request(
        attributes: BabyTimerAttributes(babyId: session.babyId, kind: session.kind.rawValue),
        content: content
      )
      return nil
    } catch {
      activity = nil
      return error.localizedDescription
    }
  }
}
