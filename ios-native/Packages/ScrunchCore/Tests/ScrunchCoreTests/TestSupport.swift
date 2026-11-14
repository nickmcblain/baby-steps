import Foundation
@testable import ScrunchCore

/// UK app: pin tests to Europe/London and en-GB so they run the same on any machine (and cover BST).
let london: Calendar = calendar("en_GB")

func calendar(_ localeIdentifier: String, timeZone: String = "Europe/London") -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: timeZone)!
  calendar.locale = Locale(identifier: localeIdentifier)
  return calendar
}

func display(_ localeIdentifier: String, weight: WeightPreference = .automatic) -> DisplayFormat {
  DisplayFormat(calendar: calendar(localeIdentifier), weightPreference: weight)
}

let gb = display("en_GB")

/// `new Date(y, m, d, h, min).getTime()` with a JS 0-based month.
func at(_ year: Int, _ jsMonth: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> EpochMs {
  london.at(year: year, month: jsMonth + 1, day: day, hour: hour, minute: minute)
}

let DAY: Double = 86_400_000
