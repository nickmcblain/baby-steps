import ScrunchCore
import SwiftUI
import XCTest
@testable import Scrunch

/// PR screenshots of the Home quick-log panel, bottle entry, and running breast timer.
/// Export with `SCRUNCH_SHOT_DIR=/path xcodebuild ... -only-testing:ScrunchTests/QuickLogScreenshotTests`.
@MainActor
final class QuickLogScreenshotTests: XCTestCase {
  private let baby = Baby(id: "b1", name: "Ada", dateOfBirth: 1_704_067_200_000, weightGrams: 3_400)
  private var convex: ConvexService!
  private var entitlements: Entitlements!
  private var gate: LogGate!

  override func setUp() async throws {
    convex = ConvexService(deploymentUrl: "https://example.invalid")
    entitlements = Entitlements()
    gate = LogGate(entitlements: entitlements)
    await TimerStore.shared.stop()
  }

  override func tearDown() async throws {
    await TimerStore.shared.stop()
  }

  func testHomePanelLight() async throws {
    try await snapshot("home-panel-light", panel(scheme: .light))
  }

  func testHomePanelDark() async throws {
    try await snapshot("home-panel-dark", panel(scheme: .dark))
  }

  func testBottleEntry() async throws {
    let view = FeedManualView(babyId: baby.id, handoff: nil, kind: .bottle)
      .environment(convex)
      .environment(AppRouter())
      .environment(SaveFeedback())
      .environment(gate)
      .preferredColorScheme(.light)
    try await snapshot("bottle-entry", view)
  }

  func testRunningBreastTimer() async throws {
    let now = Date().epochMs
    let session = TimerSession.started(kind: .feed, side: .left, babyId: baby.id, babyName: baby.name, now: now - 7 * 60_000)
    await TimerStore.shared.update(session)
    let view = VStack(alignment: .leading, spacing: 16) {
      header
      QuickLogPanel(baby: baby, lastFeed: lastFeed(now: now), now: now)
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(C.bg)
    .environment(convex)
    .environment(AppRouter())
    .environment(TimerStore.shared)
    .environment(UndoCenter())
    .environment(SaveFeedback())
    .environment(gate)
    .preferredColorScheme(.light)
    try await snapshot("running-breast-timer", view)
  }

  private func panel(scheme: ColorScheme) -> some View {
    let now = Date().epochMs
    return VStack(alignment: .leading, spacing: 16) {
      header
      QuickLogPanel(baby: baby, lastFeed: lastFeed(now: now), now: now)
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(C.bg)
    .environment(convex)
    .environment(AppRouter())
    .environment(TimerStore.shared)
    .environment(UndoCenter())
    .environment(SaveFeedback())
    .environment(gate)
    .preferredColorScheme(scheme)
  }

  private var header: some View {
    HStack {
      Text(baby.name).font(.app(.displayBold, 32)).foregroundStyle(C.ink)
      Spacer()
      Text("Today").font(.app(.bold, 16)).foregroundStyle(C.ink)
    }
  }

  private func lastFeed(now: EpochMs) -> Event {
    Event(loggedAt: now - 2 * 3_600_000, kind: .feed, feedKind: .breast, side: .left, durationMinutes: 12)
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
      try image.pngData()?.write(to: url)
    }
    let attachment = XCTAttachment(image: image)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
