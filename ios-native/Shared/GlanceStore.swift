import Foundation
import ScrunchCore

/// The home-screen widget payload lives in the shared app group so the extension can read it.
enum GlanceStore {
  static let appGroup = "group.com.nickmcblain.babysteps"
  static let widgetKind = "BabyGlanceWidget"

  static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

  static func load() -> GlanceSnapshot? {
    guard let data = defaults.data(forKey: GlanceSnapshot.storageKey) else { return nil }
    return try? JSONDecoder().decode(GlanceSnapshot.self, from: data)
  }

  /// Returns false when the payload is unchanged (so callers can skip a widget reload).
  @discardableResult
  static func save(_ snapshot: GlanceSnapshot) -> Bool {
    guard let data = try? JSONEncoder().encode(snapshot) else { return false }
    if defaults.data(forKey: GlanceSnapshot.storageKey) == data { return false }
    defaults.set(data, forKey: GlanceSnapshot.storageKey)
    return true
  }
}
