import Foundation
import os

/// Signposts for launch performance. `ScrunchUITests` reads `TimeToUsableHome` with
/// `XCTOSSignpostMetric`; Instruments shows it under the "launch" category.
@MainActor
enum LaunchMetrics {
  static let subsystem = "com.nickmcblain.babysteps"
  static let category = "launch"
  static let usableHome: StaticString = "TimeToUsableHome"

  private static let signposter = OSSignposter(subsystem: subsystem, category: category)
  private static let log = Logger(subsystem: subsystem, category: category)
  private static var interval: OSSignpostIntervalState?
  private static var homeShown = false
  private static var liveShown = false

  static func appStarted() {
    interval = signposter.beginInterval(usableHome)
  }

  /// The home screen has a baby to show (or knows there isn't one).
  static func homeUsable(fromCache: Bool) {
    guard !homeShown, let interval else { return }
    homeShown = true
    let source = fromCache ? "cache" : "live"
    let ms = sinceProcessStart()
    signposter.endInterval(usableHome, interval, "\(source, privacy: .public)")
    log.notice("Usable home \(ms, privacy: .public) ms after process start (\(source, privacy: .public))")
  }

  /// Convex has answered the home queries this session.
  static func homeLive() {
    guard !liveShown else { return }
    liveShown = true
    let ms = sinceProcessStart()
    signposter.emitEvent("HomeLiveData")
    log.notice("Live home data \(ms, privacy: .public) ms after process start")
  }

  /// Wall time since the kernel started this process, so pre-`main` work is counted too.
  private static func sinceProcessStart() -> Int {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.size
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0 else { return -1 }
    let start = info.kp_proc.p_starttime
    let startSeconds = Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000
    return Int((Date().timeIntervalSince1970 - startSeconds) * 1000)
  }
}
