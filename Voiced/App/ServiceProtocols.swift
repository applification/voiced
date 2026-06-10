import AppKit
import CoreGraphics
import Foundation

@MainActor
protocol HotkeyListening: AnyObject {
    typealias KeyHandler = (_ type: CGEventType, _ keyCode: CGKeyCode, _ flags: CGEventFlags) -> Void

    func startListening(handler: @escaping KeyHandler)
    func stopListening()
}

protocol AudioRecording: AnyObject {
    func start() throws
    func stop() -> URL?
    func currentLevel() -> Double
}

@MainActor
protocol AppTranscribing: AnyObject {
    var isSelectedModelLoaded: Bool { get }
    var onModelProgress: ((ModelLoadProgress) -> Void)? { get set }

    func loadModelIfNeeded() async throws
    func transcribeFile(at url: URL) async throws -> String
    func startLiveTranscription(onUpdate: @escaping @MainActor (LiveTranscriptState) -> Void) async throws
    func stopLiveTranscription() async -> String
}

@MainActor
protocol OutputPerforming: AnyObject {
    func copyToClipboard(_ text: String)
    func paste(_ text: String, into targetApplication: NSRunningApplication?)
}

@MainActor
protocol IndicatorPresenting: AnyObject {
    func show(state: IndicatorState)
    func hide()
}

@MainActor
protocol CursorIndicatorPresenting: AnyObject {
    var hasReviewText: Bool { get }

    func showTranscribingAtCursor()
    func showLiveTranscriptAtCursor(state: LiveTranscriptState, onCancel: @escaping () -> Void)
    func updateLiveTranscript(_ state: LiveTranscriptState)
    func showReviewAtCursor(text: String, onCopy: @escaping (String) -> Void)
    func hide()
    func hideImmediately()
}

@MainActor
protocol PermissionManaging: AnyObject {
    var micAuthorized: Bool { get }

    func refreshStatuses()
    func requestMicrophone(completion: @Sendable @escaping (Bool) -> Void)
}

@MainActor
protocol SoundCuePlaying: AnyObject {
    func playActivation()
    func playDeactivation()
}

@MainActor
protocol TelemetryReporting: AnyObject {
    func configure(settings: SettingsStore)
    func setBasicDiagnosticsEnabled(_ enabled: Bool)
    func capture(_ event: TelemetryEvent, properties: [String: Any])
    func captureError(_ category: TelemetryErrorCategory, properties: [String: Any])
}

extension HotkeyManager: HotkeyListening {}
extension AudioRecorder: AudioRecording {}
extension WhisperKitTranscriptionService: AppTranscribing {}
extension OutputManager: OutputPerforming {}
extension FloatingIndicator: IndicatorPresenting {}
extension CursorMicroIndicator: CursorIndicatorPresenting {}
extension PermissionManager: PermissionManaging {}
extension SoundCuePlayer: SoundCuePlaying {}
extension TelemetryService: TelemetryReporting {}
