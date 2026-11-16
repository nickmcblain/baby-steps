import SwiftUI
import XCTest
@testable import Scrunch

/// Light and dark shots of the first in-app frame after UILaunchScreen.
/// Export with `SCRUNCH_SHOT_DIR=/path xcodebuild ... -only-testing:ScrunchTests/SplashScreenshotTests`.
@MainActor
final class SplashScreenshotTests: XCTestCase {
  func testSplashLoadingLight() async throws {
    try await snapshot("loading-light", SplashLoadingView().preferredColorScheme(.light))
  }

  func testSplashLoadingDark() async throws {
    try await snapshot("loading-dark", SplashLoadingView().preferredColorScheme(.dark))
  }

  private var window: UIWindow {
    get throws {
      try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first)
    }
  }

  private func snapshot(_ name: String, _ view: some View, settle: Double = 0.8) async throws {
    let window = try window
    let previous = window.rootViewController
    defer { window.rootViewController = previous }
    window.rootViewController = UIHostingController(rootView: view)
    try await Task.sleep(for: .seconds(settle))
    let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
      window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
    }
    if let dir = ProcessInfo.processInfo.environment["SCRUNCH_SHOT_DIR"] {
      let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
      try FileManager.default.createDirectory(at: URL(fileURLWithPath: dir), withIntermediateDirectories: true)
      try image.pngData()?.write(to: url)
    }
    let attachment = XCTAttachment(image: image)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
