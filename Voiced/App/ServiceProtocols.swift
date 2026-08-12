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
    @discardableResult func copyToClipboard(_ text: String) -> OutputResult
    func insert(_ text: String, into targetApplication: NSRunningApplication?) async -> OutputResult
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
protocol MicrophonePermissionManaging: AnyObject {
    var micAuthorized: Bool { get }

    func refreshStatuses()
    func requestMicrophone(completion: @Sendable @escaping (Bool) -> Void)
}

@MainActor
protocol SelectedTextCapturing: AnyObject {
    func capture(from context: DestinationApplicationContext) async throws -> SelectedTextCaptureResult
}

@MainActor
protocol SoundCuePlaying: AnyObject {
    func playActivation()
    func playDeactivation()
}

extension HotkeyManager: HotkeyListening {}
extension WhisperKitTranscriptionService: AppTranscribing {}
extension OutputManager: OutputPerforming {}
extension TranscriptProcessingService: TranscriptProcessing {}
extension ReminderExportService: ReminderExporting {}
extension FloatingIndicator: IndicatorPresenting {}
extension MicrophonePermissionManager: MicrophonePermissionManaging {}
extension SelectedTextCaptureService: SelectedTextCapturing {}
extension SoundCuePlayer: SoundCuePlaying {}
