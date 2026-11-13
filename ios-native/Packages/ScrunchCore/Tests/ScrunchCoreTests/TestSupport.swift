import Foundation
@testable import ScrunchCore

/// UK app: pin tests to Europe/London so they run the same on any machine (and cover BST).
let london: Calendar = {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "Europe/London")!
  return calendar
}()

/// `new Date(y, m, d, h, min).getTime()` with a JS 0-based month.
func at(_ year: Int, _ jsMonth: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> EpochMs {
  london.at(year: year, month: jsMonth + 1, day: day, hour: hour, minute: minute)
}

let DAY: Double = 86_400_000
