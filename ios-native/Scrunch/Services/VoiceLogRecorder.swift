import AVFoundation
import Foundation
import Observation
import ScrunchCore
import UIKit

/// Port of lib/useVoiceLog.ts: tap to record, tap again to send to `voiceLog:logFromAudio`.
@MainActor
@Observable
final class VoiceLogRecorder {
  struct Alert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
  }

  private static let maxSeconds: TimeInterval = 30
  private static let minSeconds: TimeInterval = 0.9
  private static let minBytes = 2_500

  private(set) var recording = false
  private(set) var busy = false
  private(set) var status: String?
  var alert: Alert?

  @ObservationIgnored private var recorder: AVAudioRecorder?
  @ObservationIgnored private var startedAt = Date()
  @ObservationIgnored private var maxTimer: Task<Void, Never>?
  @ObservationIgnored private var starting = false
  @ObservationIgnored private var onAutoFinish: ((VoiceLogResult) -> Void)?

  private var fileURL: URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("voice-log.m4a")
  }

  /// Start, or stop and send. Returns the result when a log was sent.
  /// `onAutoFinish` receives the result when the 30-second cap stops the recording.
  func toggle(babyId: BabyID, convex: ConvexService, onAutoFinish: @escaping (VoiceLogResult) -> Void) async -> VoiceLogResult? {
    if busy || starting { return nil }
    if recording { return await finish(babyId: babyId, convex: convex) }
    self.onAutoFinish = onAutoFinish
    await start(babyId: babyId, convex: convex)
    return nil
  }

  func cancel() {
    maxTimer?.cancel()
    maxTimer = nil
    guard recording else { return }
    recording = false
    status = nil
    recorder?.stop()
  }

  private func start(babyId: BabyID, convex: ConvexService) async {
    starting = true
    defer { starting = false }
    #if targetEnvironment(simulator)
    alert = Alert(
      title: String(localized: "Use a real phone"),
      message: String(localized: "iOS Simulator mic is usually silent, so Whisper hears nothing. Run on a device.")
    )
    return
    #else
    guard await ensureMicPermission() else { return }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
      try session.setActive(true)
      try? FileManager.default.removeItem(at: fileURL)
      let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 1,
        AVEncoderBitRateKey: 128_000,
        AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue,
      ]
      let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
      recorder.isMeteringEnabled = true
      guard recorder.record() else { throw RecordError.couldNotStart }
      self.recorder = recorder
      recording = true
      startedAt = Date()
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      status = String(localized: "Listening… tap again to send")
      maxTimer?.cancel()
      maxTimer = Task { [weak self] in
        try? await Task.sleep(for: .seconds(Self.maxSeconds))
        guard let self, !Task.isCancelled, self.recording else { return }
        if let result = await self.finish(babyId: babyId, convex: convex) {
          self.onAutoFinish?(result)
        }
      }
    } catch {
      recording = false
      status = nil
      alert = Alert(title: String(localized: "Could not record"), message: error.localizedDescription.isEmpty ? "Try again" : error.localizedDescription)
    }
    #endif
  }

  private func finish(babyId: BabyID, convex: ConvexService) async -> VoiceLogResult? {
    maxTimer?.cancel()
    maxTimer = nil
    guard recording, let recorder else { return nil }
    recording = false

    let elapsed = Date().timeIntervalSince(startedAt)
    recorder.stop()
    if elapsed < Self.minSeconds {
      status = nil
      alert = Alert(title: String(localized: "Too short"), message: String(localized: "Tap Speak, talk for a second or two, then tap again to send."))
      return nil
    }

    guard let data = try? Data(contentsOf: fileURL) else {
      status = nil
      alert = Alert(title: String(localized: "Voice log"), message: String(localized: "No recording saved — try again."))
      return nil
    }
    if data.count < Self.minBytes {
      status = nil
      alert = Alert(title: String(localized: "No audio captured"), message: String(localized: "Mic produced an empty clip. Check mic permission and try again."))
      return nil
    }

    busy = true
    status = String(localized: "Logging…")
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    defer {
      busy = false
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    let base64 = data.base64EncodedString()
    guard base64.count <= API.voiceLog.maxAudioBase64Length else {
      status = nil
      alert = Alert(title: String(localized: "Voice log"), message: String(localized: "That clip is too long. Keep it under 30 seconds."))
      return nil
    }

    do {
      let result = try await convex.action(API.voiceLog.logFromAudio(babyId: babyId, audioBase64: base64))
      UINotificationFeedbackGenerator().notificationOccurred(.success)
      status = nil
      return result
    } catch {
      UINotificationFeedbackGenerator().notificationOccurred(.error)
      status = nil
      alert = Alert(title: String(localized: "Voice log"), message: UserMessage.from(error, fallback: String(localized: "Could not log from voice")))
      return nil
    }
  }

  private func ensureMicPermission() async -> Bool {
    switch AVAudioApplication.shared.recordPermission {
    case .granted:
      return true
    case .undetermined:
      let granted = await AVAudioApplication.requestRecordPermission()
      if !granted {
        alert = Alert(title: String(localized: "Microphone needed"), message: String(localized: "Allow mic access to log feeds and sleeps hands-free."))
      }
      return granted
    default:
      alert = Alert(title: String(localized: "Microphone needed"), message: String(localized: "Allow mic access in Settings to speak a log."))
      return false
    }
  }

  private enum RecordError: LocalizedError {
    case couldNotStart
    var errorDescription: String? { "Try again" }
  }
}
