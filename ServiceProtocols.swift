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
}

@MainActor
protocol OutputPerforming: AnyObject {
    func copyToClipboard(_ text: String)
    func pastePreservingClipboard(_ text: String, targetApplication: NSRunningApplication?)
}

@MainActor
protocol IndicatorPresenting: AnyObject {
    func show(state: IndicatorState)
    func hide()
}

@MainActor
protocol CursorIndicatorPresenting: AnyObject {
    func showTranscribingAtCursor()
    func hide()
    func hideImmediately()
}

@MainActor
protocol PermissionManaging: AnyObject {
    var micAuthorized: Bool { get }
    var accessibilityEnabled: Bool { get }

    func refreshStatuses()
    func requestMicrophone(completion: @Sendable @escaping (Bool) -> Void)
    func requestAccessibilityPrompt()
    func openAccessibilityPrefs()
}

@MainActor
protocol SoundCuePlaying: AnyObject {
    func playActivation()
    func playDeactivation()
}

extension HotkeyManager: HotkeyListening {}
extension AudioRecorder: AudioRecording {}
extension WhisperKitTranscriptionService: AppTranscribing {}
extension OutputManager: OutputPerforming {}
extension FloatingIndicator: IndicatorPresenting {}
extension CursorMicroIndicator: CursorIndicatorPresenting {}
extension PermissionManager: PermissionManaging {}
extension SoundCuePlayer: SoundCuePlaying {}
