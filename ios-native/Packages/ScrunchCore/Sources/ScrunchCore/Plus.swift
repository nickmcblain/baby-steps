import Foundation

/// Scrunch Plus: what stays free, what Plus adds, and the copy around it.
/// Prices and trial lengths always come from StoreKit, never from here.
public enum Plus {
  /// One subscription group. Keep in sync with `PLUS_PRODUCT_IDS` in convex/lib/appStore.ts.
  public static let monthlyProductID = "com.nickmcblain.babysteps.plus.monthly"
  public static let annualProductID = "com.nickmcblain.babysteps.plus.annual"
  public static let productIDs = [monthlyProductID, annualProductID]

  /// Apple's standard EULA. App Review also needs a privacy policy link before release.
  public static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

  public enum Feature: Sendable {
    case ask, patterns

    public var title: String {
      switch self {
      case .ask: "Ask is part of Plus"
      case .patterns: "Patterns are part of Plus"
      }
    }

    public var pitch: String {
      switch self {
      case .ask:
        "Ask questions about feeds, sleep and nappies and get answers grounded in NHS guidance, using what you've logged."
      case .patterns:
        "See how feeds, sleep, tummy time and nappies change over 7, 14 and 30 days, so you can spot a rhythm forming."
      }
    }
  }

  public static let includes = [
    "Ask: answers grounded in NHS guidance, using your logs",
    "Feed, sleep, tummy time and nappy patterns over 7, 14 and 30 days",
  ]

  /// The short form, for the paywall where space is tight.
  public static let alwaysFreeSummary = "Every log, timers, widgets, the Live Activity, reminders and partner sharing stay free."

  public static let alwaysFree = [
    "Every log: feeds, sleep, nappies, pumping, growth and more",
    "Timers, widgets and the Live Activity",
    "Reminders, the timeline and today at a glance",
    "Sharing your baby with a partner",
  ]

  public static let renewalTerms =
    "Plus renews automatically at the price shown unless you cancel at least 24 hours before the end of the trial or current period. Cancel any time in Settings, or from Manage subscription in Scrunch. Payment is taken by Apple."

  public enum PeriodUnit: Sendable { case day, week, month, year }

  /// "2 weeks", "1 month", "1 year", matching how StoreKit's own paywall words periods.
  public static func duration(value: Int, unit: PeriodUnit) -> String {
    switch unit {
    case .day: plural(value, "day")
    case .week: plural(value, "week")
    case .month: plural(value, "month")
    case .year: plural(value, "year")
    }
  }

  /// "£2.99 a month", "£24.99 a year", "£7.99 every 3 months".
  public static func renewalPrice(_ price: String, value: Int, unit: PeriodUnit) -> String {
    if value == 1 {
      switch unit {
      case .day: return "\(price) a day"
      case .week: return "\(price) a week"
      case .month: return "\(price) a month"
      case .year: return "\(price) a year"
      }
    }
    return "\(price) every \(duration(value: value, unit: unit))"
  }

  public static func callToAction(trialLength: String?) -> String {
    trialLength.map { "Try Plus free for \($0)" } ?? "See Scrunch Plus"
  }

  private static func plural(_ n: Int, _ word: String) -> String {
    "\(n) \(word)\(n == 1 ? "" : "s")"
  }

  static func longDate(_ date: Date, calendar: Calendar) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_GB")
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "EEEE d MMMM"
    return formatter.string(from: date)
  }
}

/// The user's active Plus entitlement, as StoreKit reports it.
public struct PlusStatus: Equatable, Sendable {
  public var productID: String
  public var expiresAt: Date?
  public var inTrial: Bool
  public var willAutoRenew: Bool
  public var familyShared: Bool

  public init(productID: String, expiresAt: Date?, inTrial: Bool, willAutoRenew: Bool, familyShared: Bool) {
    self.productID = productID
    self.expiresAt = expiresAt
    self.inTrial = inTrial
    self.willAutoRenew = willAutoRenew
    self.familyShared = familyShared
  }

  public var planName: String {
    productID == Plus.annualProductID ? "Plus, yearly" : "Plus, monthly"
  }

  public func summary(calendar: Calendar = .current) -> String {
    if familyShared { return "Shared with you through Family Sharing" }
    guard let expiresAt else { return "Active" }
    let date = Plus.longDate(expiresAt, calendar: calendar)
    switch (inTrial, willAutoRenew) {
    case (true, true): return "Free trial until \(date), then renews"
    case (true, false): return "Free trial until \(date). It won't renew"
    case (false, true): return "Renews on \(date)"
    case (false, false): return "Ends on \(date). It won't renew"
    }
  }
}

/// One local notification a couple of days before a free trial turns into a charge.
/// Only scheduled when the parent says yes.
public enum TrialReminder {
  public static let identifier = "plus-trial-reminder"
  public static let title = "Your Scrunch Plus trial ends soon"

  public static let consentTitle = "Remind you before the trial ends?"
  public static let consentMessage =
    "We'll send one notification two days before your free trial ends, so you can decide whether to keep Plus."

  /// 10am, two calendar days before the trial ends; nil once that has passed.
  public static func fireDate(trialEndsAt: Date, now: Date, calendar: Calendar = .current) -> Date? {
    guard let twoDaysBefore = calendar.date(byAdding: .day, value: -2, to: trialEndsAt),
          let morning = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: twoDaysBefore)
    else { return nil }
    return morning > now ? morning : nil
  }

  public static func body(trialEndsAt: Date, renewalPrice: String?, calendar: Calendar = .current) -> String {
    let date = Plus.longDate(trialEndsAt, calendar: calendar)
    let then = renewalPrice.map { "After that, Plus is \($0) unless you cancel." } ?? "After that, Plus renews unless you cancel."
    return "Your free trial ends on \(date). \(then) To cancel, use Manage subscription in Scrunch, or Settings > your name > Subscriptions."
  }
}
