import Foundation
import AppKit

final class AppCoordinator {
    private let settings: SettingsStore
    private let hotkeys = HotkeyManager()
    private let recorder = AudioRecorder()
    private let transcriber = PlaceholderTranscriptionService()
    private let output = OutputManager()
    private let lastCapture = LastCaptureStore()
    private let indicator = FloatingIndicator()
    private let permissions = PermissionManager()

    private var isRecording = false
    private let rightCommandKeyCode: CGKeyCode = 54 // Right Command keycode on macOS
    private var isPTTDown = false

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func start() {
        permissions.refreshStatuses()
        hotkeys.startListening { [weak self] (type: CGEventType, keyCode: CGKeyCode, flags: CGEventFlags) in
            guard let self else { return }
            switch type {
            case .flagsChanged:
                guard keyCode == self.rightCommandKeyCode else { return }
                let isDown = flags.contains(.maskCommand)
                if isDown && !self.isPTTDown { self.isPTTDown = true; self.handleKeyDown() }
                if !isDown && self.isPTTDown { self.isPTTDown = false; self.handleKeyUp() }
            default:
                break
            }
        }
    }

    private func handleKeyDown() {
        guard !isRecording else { return }
        guard permissions.micAuthorized else {
            permissions.requestMicrophone { _ in }
            return
        }
        do {
            try recorder.start()
            isRecording = true
            indicator.show(state: IndicatorState.recording)
        } catch {
            NSLog("Failed to start recording: \(String(describing: error))")
        }
    }

    private func handleKeyUp() {
        guard isRecording else { return }
        isRecording = false
        indicator.show(state: IndicatorState.transcribing)
        let url = recorder.stop()
        guard let url else {
            indicator.hide()
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.transcriber.loadModelIfNeeded()
                let text = try await self.transcriber.transcribeFile(at: url)
                self.lastCapture.set(text, autoClearAfter: TimeInterval(self.settings.copyLastTranscriptClearsAfterMinutes * 60))
                if self.settings.outputMode == .clipboardPaste {
                    self.output.pastePreservingClipboard(text)
                } else {
                    self.output.copyToClipboard(text)
                }
                _ = text.count // avoid logging sensitive content
            } catch {
                NSLog("Transcription error: \(String(describing: error))")
            }
            // Cleanup temp audio
            try? FileManager.default.removeItem(at: url)
            self.indicator.hide()
        }
    }
}
