import Foundation

/// The Scrunch subscription and the copy around it. Prices always come from StoreKit, never from here.
public enum Subscription {
  /// One subscription group. Keep in sync with `SUBSCRIPTION_PRODUCT_IDS` in convex/lib/appStore.ts.
  public static let monthlyProductID = "com.nickmcblain.babysteps.monthly"
  public static let yearlyProductID = "com.nickmcblain.babysteps.yearly"
  public static let productIDs = [monthlyProductID, yearlyProductID]

  /// Apple's standard EULA. App Review also needs a privacy policy link before release.
  public static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

  public static let includes = [
    "Unlimited feeds, nappies, pumping, growth and every other log",
    "Ask: answers grounded in NHS guidance, using your logs",
    "Feed, tummy time and nappy patterns over 7, 14 and 30 days",
    "One subscription covers everyone you share your baby with",
  ]

  public static let alwaysFree =
    "Sleep logs, sleep timers, the sleep Live Activity and sleep patterns stay free for good. Everything you've already logged stays readable."

  public static let renewalTerms =
    "Your subscription renews automatically at the price shown unless you cancel at least 24 hours before the end of the current period. Cancel any time in Settings, or from Manage subscription in Scrunch. Payment is taken by Apple."

  public enum Feature: Sendable {
    case ask, patterns

    public var title: String {
      switch self {
      case .ask: "Ask comes with a subscription"
      case .patterns: "Patterns come with a subscription"
      }
    }

    public var pitch: String {
      switch self {
      case .ask:
        "You've used your free entries. Subscribe to keep asking about feeds, sleep and nappies, with answers grounded in NHS guidance."
      case .patterns:
        "You've used your free entries. Subscribe to keep seeing how feeds, tummy time and nappies change over 7, 14 and 30 days. Sleep patterns stay free."
      }
    }
  }

  public enum PeriodUnit: Sendable { case day, week, month, year }

  /// "£2.99 a month", "£9.99 a year", "£7.99 every 3 months".
  public static func renewalPrice(_ price: String, value: Int, unit: PeriodUnit) -> String {
    if value == 1 {
      switch unit {
      case .day: return "\(price) a day"
      case .week: return "\(price) a week"
      case .month: return "\(price) a month"
      case .year: return "\(price) a year"
      }
    }
    let word = switch unit {
    case .day: "days"
    case .week: "weeks"
    case .month: "months"
    case .year: "years"
    }
    return "\(price) every \(value) \(word)"
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

/// The user's active subscription, as StoreKit reports it.
public struct PlanStatus: Equatable, Sendable {
  public var productID: String
  public var expiresAt: Date?
  public var willAutoRenew: Bool
  public var familyShared: Bool

  public init(productID: String, expiresAt: Date?, willAutoRenew: Bool, familyShared: Bool) {
    self.productID = productID
    self.expiresAt = expiresAt
    self.willAutoRenew = willAutoRenew
    self.familyShared = familyShared
  }

  public var planName: String {
    productID == Subscription.yearlyProductID ? "Yearly subscription" : "Monthly subscription"
  }

  public func summary(calendar: Calendar = .current) -> String {
    if familyShared { return "Shared with you through Family Sharing" }
    guard let expiresAt else { return "Active" }
    let date = Subscription.longDate(expiresAt, calendar: calendar)
    return willAutoRenew ? "Renews on \(date)" : "Ends on \(date). It won't renew"
  }
}
