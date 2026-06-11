import AppKit
import CoreGraphics
import Foundation

@MainActor
protocol HotkeyListening: AnyObject {
    typealias KeyHandler = (_ type: CGEventType, _ keyCode: CGKeyCode, _ flags: CGEventFlags) -> Void

    func startListening(handler: @escaping KeyHandler)
    func stopListening()
}

@MainActor
protocol AppTranscribing: AnyObject {
    var isSelectedModelLoaded: Bool { get }
    var onModelProgress: ((ModelLoadProgress) -> Void)? { get set }

    func loadModelIfNeeded() async throws
    func transcribeFile(at url: URL) async throws -> String
    func startLiveTranscription(
        onUpdate: @escaping @MainActor (LiveTranscriptState) -> Void,
        onAudioLevel: @escaping @MainActor (Double) -> Void
    ) async throws
    func stopLiveTranscription() async -> String
}

@MainActor
protocol OutputPerforming: AnyObject {
    func copyToClipboard(_ text: String)
}

@MainActor
protocol TranscriptProcessing: AnyObject {
    var availability: TranscriptProcessingAvailability { get }

    func process(_ transcript: String, profile: TranscriptProcessingProfile) async throws -> String
}

@MainActor
protocol ReminderExporting: AnyObject {
    func checklistItemCount(in text: String) -> Int
    func reminderLists(requestingAccess: Bool) async throws -> [ReminderListOption]
    func exportChecklist(from text: String, to listID: String?) async throws -> Int
}

@MainActor
protocol IndicatorPresenting: AnyObject {
    func show(state: IndicatorState)
    func updateAudioLevel(_ level: Double)
    func hide()
}

@MainActor
protocol CursorIndicatorPresenting: AnyObject {
    var hasReviewText: Bool { get }

    func showTranscribingAtCursor()
    func showLiveTranscriptAtCursor(state: LiveTranscriptState, onCancel: @escaping () -> Void)
    func updateLiveTranscript(_ state: LiveTranscriptState)
    func updateAudioLevel(_ level: Double)
    @discardableResult
    func showReviewAtCursor(
        text: String,
        processingAvailability: TranscriptProcessingAvailability,
        onCopy: @escaping (String) -> Void,
        onProcess: @escaping (TranscriptProcessingProfile, String) async -> String,
        onLoadReminderLists: @escaping (Bool) async -> [ReminderListOption],
        onExportToReminders: @escaping (String, String?) async -> ReminderExportResult,
        onDropRejected: @escaping () -> Void
    ) -> String
    func hide()
    func hideImmediately()
}

@MainActor
protocol MicrophonePermissionManaging: AnyObject {
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
extension WhisperKitTranscriptionService: AppTranscribing {}
extension OutputManager: OutputPerforming {}
extension TranscriptProcessingService: TranscriptProcessing {}
extension ReminderExportService: ReminderExporting {}
extension FloatingIndicator: IndicatorPresenting {}
extension CursorMicroIndicator: CursorIndicatorPresenting {}
extension MicrophonePermissionManager: MicrophonePermissionManaging {}
extension SoundCuePlayer: SoundCuePlaying {}
extension TelemetryService: TelemetryReporting {}
