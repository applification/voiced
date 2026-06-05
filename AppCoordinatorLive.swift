import Foundation
import AppKit
import os

@MainActor
final class AppCoordinator {
    private let settings: SettingsStore
    private let hotkeys = HotkeyManager()
    private let recorder = AudioRecorder()
    private let transcriber: WhisperKitTranscriptionService
    private let output = OutputManager()
    private let lastCapture: LastCaptureStore
    private let indicator = FloatingIndicator()
    private let permissions = PermissionManager()
    private let soundCues: SoundCuePlayer
    
    private static let logger = Logger(subsystem: "net.applification.voiced", category: "coordinator")

    private var isRecording = false
    private var isTranscribing = false
    private var targetApplication: NSRunningApplication?
    private var modelApprovalObserver: NSObjectProtocol?
    private var meteringTask: Task<Void, Never>?
    private let rightCommandKeyCode: CGKeyCode = 54 // Right Command keycode on macOS
    private var isPTTDown = false

    init(settings: SettingsStore, lastCapture: LastCaptureStore) {
        self.settings = settings
        self.lastCapture = lastCapture
        self.transcriber = WhisperKitTranscriptionService(settings: settings)
        self.soundCues = SoundCuePlayer(settings: settings)
    }

    func start() {
        AppCoordinator.logger.info("AppCoordinator start() called")
        permissions.refreshStatuses()
        AppCoordinator.logger.info("Permissions — mic: \(self.permissions.micAuthorized, privacy: .public)")
        modelApprovalObserver = NotificationCenter.default.addObserver(
            forName: .voicedModelApprovalChanged,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.warmUpTranscriptionService(reason: "model approval")
            }
        }
        warmUpTranscriptionService(reason: "app start")
        hotkeys.startListening { [weak self] (type: CGEventType, keyCode: CGKeyCode, flags: CGEventFlags) in
            guard let self else { return }
            switch type {
            case .flagsChanged:
                AppCoordinator.logger.debug("flagsChanged keyCode=\(keyCode, privacy: .public) flags=\(UInt64(flags.rawValue), privacy: .public)")
                guard keyCode == self.rightCommandKeyCode else { return }
                let isDown = flags.contains(.maskCommand)
                if isDown && !self.isPTTDown { self.isPTTDown = true; self.handleKeyDown() }
                if !isDown && self.isPTTDown { self.isPTTDown = false; self.handleKeyUp() }
            default:
                break
            }
        }
    }

    private func warmUpTranscriptionService(reason: String) {
        guard settings.modelDownloadsApproved else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let shouldShowLoader = reason != "app start" && !self.transcriber.isSelectedModelLoaded
            if shouldShowLoader {
                self.indicator.show(state: .loadingModel(self.settings.transcriptionModel.label))
            }
            do {
                AppCoordinator.logger.info("Warming transcription service; reason=\(reason, privacy: .public)")
                try await self.transcriber.loadModelIfNeeded()
                AppCoordinator.logger.info("Transcription service warm")
            } catch {
                AppCoordinator.logger.error("Transcription warm-up failed: \(String(describing: error), privacy: .public)")
                if shouldShowLoader {
                    self.indicator.show(state: .error("Model load failed"))
                }
            }
            if shouldShowLoader {
                try? await Task.sleep(nanoseconds: 650_000_000)
                self.indicator.hide()
            }
        }
    }

    private func handleKeyDown() {
        AppCoordinator.logger.debug("handleKeyDown() invoked; isRecording=\(self.isRecording, privacy: .public) isTranscribing=\(self.isTranscribing, privacy: .public)")
        guard !isRecording, !isTranscribing else { return }
        guard permissions.micAuthorized else {
            AppCoordinator.logger.warning("Mic not authorized; requesting permission")
            permissions.requestMicrophone { [weak self] _ in
                Task { @MainActor in
                    self?.permissions.refreshStatuses()
                }
            }
            return
        }
        do {
            targetApplication = NSWorkspace.shared.frontmostApplication
            try recorder.start()
            AppCoordinator.logger.info("Recording started")
            isRecording = true
            soundCues.playActivation()
            startMeteringIndicator()
        } catch {
            AppCoordinator.logger.error("Failed to start recording: \(String(describing: error), privacy: .public)")
        }
    }

    private func handleKeyUp() {
        AppCoordinator.logger.debug("handleKeyUp() invoked; isRecording was true")
        guard isRecording else { return }
        isRecording = false
        soundCues.playDeactivation()
        stopMeteringIndicator()
        if transcriber.isSelectedModelLoaded {
            indicator.show(state: .transcribing)
        } else {
            indicator.show(state: .loadingModel(settings.transcriptionModel.label))
        }
        let url = recorder.stop()
        let targetApplication = targetApplication
        self.targetApplication = nil
        AppCoordinator.logger.debug("Recorder stopped; url present=\(url != nil, privacy: .public)")
        guard let url else {
            indicator.hide()
            return
        }
        isTranscribing = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isTranscribing = false
                try? FileManager.default.removeItem(at: url)
            }
            do {
                AppCoordinator.logger.info("Loading transcription service")
                try await self.transcriber.loadModelIfNeeded()
                self.indicator.show(state: .transcribing)
                AppCoordinator.logger.info("Starting transcription for \(url.lastPathComponent, privacy: .public)")
                let text = try await self.transcriber.transcribeFile(at: url)
                AppCoordinator.logger.info("Transcription completed; characters=\(text.count, privacy: .public)")
                guard !text.isEmpty else {
                    AppCoordinator.logger.warning("Transcription returned empty text")
                    self.indicator.show(state: .error("No speech detected"))
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    self.indicator.hide()
                    return
                }
                self.lastCapture.set(text, autoClearAfter: TimeInterval(self.settings.copyLastTranscriptClearsAfterMinutes * 60))
                if self.settings.outputMode == .clipboardPaste {
                    self.output.pastePreservingClipboard(text, targetApplication: targetApplication)
                } else {
                    self.output.copyToClipboard(text)
                }
                _ = text.count // avoid logging sensitive content
            } catch {
                AppCoordinator.logger.error("Transcription error: \(String(describing: error), privacy: .public)")
                self.indicator.show(state: .error("Transcription failed"))
            }
            AppCoordinator.logger.info("Indicator hide; transcription flow complete")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self.indicator.hide()
        }
    }

    private func startMeteringIndicator() {
        meteringTask?.cancel()
        indicator.show(state: .recording(level: recorder.currentLevel()))
        meteringTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.isRecording else { break }
                self.indicator.show(state: .recording(level: self.recorder.currentLevel()))
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
    }

    private func stopMeteringIndicator() {
        meteringTask?.cancel()
        meteringTask = nil
    }
}
