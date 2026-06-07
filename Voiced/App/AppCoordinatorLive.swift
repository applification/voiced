import Foundation
import AppKit
import os

@MainActor
final class AppCoordinator {
    private let settings: SettingsStore
    private let hotkeys: any HotkeyListening
    private let recorder: any AudioRecording
    private var transcriber: any AppTranscribing
    private let output: any OutputPerforming
    private let lastCapture: LastCaptureStore
    private let indicator: any IndicatorPresenting
    private let cursorIndicator: any CursorIndicatorPresenting
    private let permissions: any PermissionManaging
    private let soundCues: any SoundCuePlaying
    private let telemetry: any TelemetryReporting
    
    private static let logger = Logger(subsystem: "net.applification.voiced", category: "coordinator")

    private var captureState: CaptureState = .idle
    private var targetApplication: NSRunningApplication?
    private var modelDownloadObserver: NSObjectProtocol?
    private var meteringTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?
    private var activeRecordingURL: URL?
    private var shouldCancelCurrentCapture = false
    private var isPTTDown = false
    private var recordingStartedAt: Date?

    init(
        settings: SettingsStore,
        lastCapture: LastCaptureStore,
        hotkeys: any HotkeyListening = HotkeyManager(),
        recorder: any AudioRecording = AudioRecorder(),
        transcriber: any AppTranscribing,
        output: any OutputPerforming = OutputManager(),
        indicator: any IndicatorPresenting = FloatingIndicator(),
        cursorIndicator: any CursorIndicatorPresenting = CursorMicroIndicator(),
        permissions: any PermissionManaging = PermissionManager(),
        soundCues: any SoundCuePlaying,
        telemetry: any TelemetryReporting = TelemetryService()
    ) {
        self.settings = settings
        self.lastCapture = lastCapture
        self.hotkeys = hotkeys
        self.recorder = recorder
        self.transcriber = transcriber
        self.output = output
        self.indicator = indicator
        self.cursorIndicator = cursorIndicator
        self.permissions = permissions
        self.soundCues = soundCues
        self.telemetry = telemetry
    }

    convenience init(settings: SettingsStore, lastCapture: LastCaptureStore, telemetry: any TelemetryReporting = TelemetryService()) {
        self.init(
            settings: settings,
            lastCapture: lastCapture,
            transcriber: WhisperKitTranscriptionService(settings: settings),
            soundCues: SoundCuePlayer(settings: settings),
            telemetry: telemetry
        )
    }

    func start() {
        AppCoordinator.logger.info("AppCoordinator start() called")
        permissions.refreshStatuses()
        AppCoordinator.logger.info("Permissions — mic: \(self.permissions.micAuthorized, privacy: .public)")
        modelDownloadObserver = NotificationCenter.default.addObserver(
            forName: .voicedModelDownloadRequested,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            let source = notification.userInfo?["source"] as? String
            Task { @MainActor in
                let reason = source == "onboarding" ? "onboarding download" : "download request"
                self?.warmUpTranscriptionService(reason: reason)
            }
        }
        transcriber.onModelProgress = { [weak self] progress in
            self?.handleModelProgress(progress)
        }
        hotkeys.startListening { [weak self] (type: CGEventType, keyCode: CGKeyCode, flags: CGEventFlags) in
            guard let self else { return }
            switch type {
            case .keyDown:
                let escapeKey: CGKeyCode = 53
                guard keyCode == escapeKey else { return }
                self.cancelCurrentCapture()
            case .flagsChanged:
                AppCoordinator.logger.debug("flagsChanged keyCode=\(keyCode, privacy: .public) flags=\(UInt64(flags.rawValue), privacy: .public)")
                let hotkey = self.settings.pushToTalkHotkey
                guard keyCode == hotkey.keyCode else { return }
                let isDown = flags.contains(hotkey.eventFlag)
                if isDown && !self.isPTTDown {
                    self.isPTTDown = true
                    self.handleKeyDown()
                } else if isDown && self.isPTTDown && !self.captureState.isRecording && !self.captureState.isBusy {
                    AppCoordinator.logger.warning("Push-to-talk latch was already down while idle; treating modifier event as a fresh press")
                    self.handleKeyDown()
                }
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
            let shouldShowLoader = reason != "app start"
                && reason != "onboarding download"
                && !self.transcriber.isSelectedModelLoaded
            if shouldShowLoader {
                self.captureState = .loadingModel
                self.indicator.show(state: .loadingModel(self.settings.transcriptionModel.label))
            }
            do {
                AppCoordinator.logger.info("Warming transcription service; reason=\(reason, privacy: .public)")
                self.telemetry.capture(.modelLoadStarted, properties: [
                    "reason": reason,
                    "model": self.settings.transcriptionModel.rawValue
                ])
                try await self.transcriber.loadModelIfNeeded()
                AppCoordinator.logger.info("Transcription service warm")
                self.telemetry.capture(.modelLoadSucceeded, properties: [
                    "reason": reason,
                    "model": self.settings.transcriptionModel.rawValue
                ])
            } catch {
                AppCoordinator.logger.error("Transcription warm-up failed: \(String(describing: error), privacy: .public)")
                self.telemetry.captureError(.modelLoadFailed, properties: [
                    "reason": reason,
                    "model": self.settings.transcriptionModel.rawValue
                ])
                NotificationCenter.default.post(name: .voicedModelStatusChanged, object: self.settings.transcriptionModel)
                if shouldShowLoader {
                    self.captureState = .showingError
                    self.indicator.show(state: .error("Model load failed"))
                }
            }
            if shouldShowLoader {
                self.captureState = .idle
                try? await Task.sleep(nanoseconds: 650_000_000)
                self.indicator.hide()
            }
        }
    }

    private func handleModelProgress(_ progress: ModelLoadProgress) {
        NotificationCenter.default.post(name: .voicedModelProgressChanged, object: progress)
        guard progress.model == settings.transcriptionModel else {
            return
        }

        guard captureState.isShowingModelProgress else {
            AppCoordinator.logger.debug("Ignoring hidden model progress phase=\(progress.phase, privacy: .public)")
            return
        }

        if progress.phase == "Loaded" {
            AppCoordinator.logger.info("Model progress loaded; hiding indicator")
            captureState = .idle
            indicator.hide()
            return
        }

        let percent = Int((progress.fractionCompleted * 100).rounded())
        let label: String
        switch progress.phase {
        case "Downloading":
            label = "\(settings.transcriptionModel.label) \(percent)%"
        case "Downloaded":
            label = "\(settings.transcriptionModel.label) Ready"
        case "Preparing":
            label = "\(settings.transcriptionModel.label) Preparing"
        case "Loading":
            label = "\(settings.transcriptionModel.label) Loading"
        case "Loaded":
            label = "\(settings.transcriptionModel.label) Loaded"
        case "Specializing":
            label = "\(settings.transcriptionModel.label) Specializing"
        case "Specialized":
            label = "\(settings.transcriptionModel.label) Specialized"
        default:
            label = "\(settings.transcriptionModel.label) \(progress.phase)"
        }
        AppCoordinator.logger.info("Model progress phase=\(progress.phase, privacy: .public) percent=\(percent, privacy: .public)")
        indicator.show(state: .loadingModel(label))
    }

    private func handleKeyDown() {
        AppCoordinator.logger.debug("handleKeyDown() invoked; state=\(String(describing: self.captureState), privacy: .public)")
        guard settings.hasSeenIntroOnboarding else {
            AppCoordinator.logger.info("Ignoring push-to-talk before first-run setup is complete")
            return
        }
        guard !captureState.isBusy else { return }
        permissions.refreshStatuses()
        guard permissions.micAuthorized else {
            AppCoordinator.logger.warning("Mic not authorized; requesting permission")
            telemetry.capture(.permissionPromptShown, properties: ["permission": "microphone"])
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
            shouldCancelCurrentCapture = false
            recordingStartedAt = Date()
            lastCapture.clear()
            captureState = .recording
            telemetry.capture(.recordingStarted, properties: [
                "model": settings.transcriptionModel.rawValue,
                "output_mode": settings.outputMode.rawValue
            ])
            soundCues.playActivation()
            startMeteringIndicator()
        } catch {
            AppCoordinator.logger.error("Failed to start recording: \(String(describing: error), privacy: .public)")
            telemetry.captureError(.recordingStartFailed, properties: [:])
        }
    }

    private func handleKeyUp() {
        AppCoordinator.logger.debug("handleKeyUp() invoked; isRecording was true")
        guard captureState.isRecording else { return }
        soundCues.playDeactivation()
        stopMeteringIndicator()
        cursorIndicator.showTranscribingAtCursor()
        if transcriber.isSelectedModelLoaded {
            captureState = .transcribing
            indicator.show(state: .transcribing)
        } else {
            captureState = .loadingModel
            indicator.show(state: .loadingModel(settings.transcriptionModel.label))
        }
        let url = recorder.stop()
        let recordingDurationBucket = durationBucket(since: recordingStartedAt)
        recordingStartedAt = nil
        activeRecordingURL = url
        let targetApplication = targetApplication
        self.targetApplication = nil
        AppCoordinator.logger.debug("Recorder stopped; url present=\(url != nil, privacy: .public)")
        guard let url else {
            captureState = .idle
            cursorIndicator.hide()
            indicator.hide()
            return
        }
        transcriptionTask?.cancel()
        transcriptionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.captureState = .idle
                self.transcriptionTask = nil
                self.activeRecordingURL = nil
                self.shouldCancelCurrentCapture = false
                self.cursorIndicator.hide()
                try? FileManager.default.removeItem(at: url)
            }
            do {
                AppCoordinator.logger.info("Loading transcription service")
                self.telemetry.capture(.modelLoadStarted, properties: [
                    "reason": "transcription",
                    "model": self.settings.transcriptionModel.rawValue
                ])
                try await self.transcriber.loadModelIfNeeded()
                self.telemetry.capture(.modelLoadSucceeded, properties: [
                    "reason": "transcription",
                    "model": self.settings.transcriptionModel.rawValue
                ])
                try Task.checkCancellation()
                guard !self.shouldCancelCurrentCapture else { throw CancellationError() }
                self.captureState = .transcribing
                self.indicator.show(state: .transcribing)
                AppCoordinator.logger.info("Starting transcription for \(url.lastPathComponent, privacy: .public)")
                let text = try await self.transcriber.transcribeFile(at: url)
                try Task.checkCancellation()
                guard !self.shouldCancelCurrentCapture else { throw CancellationError() }
                AppCoordinator.logger.info("Transcription completed; characters=\(text.count, privacy: .public)")
                guard !text.isEmpty else {
                    AppCoordinator.logger.warning("Transcription returned empty text")
                    self.telemetry.captureError(.transcriptionFailed, properties: [
                        "reason": "empty_text",
                        "recording_duration": recordingDurationBucket,
                        "model": self.settings.transcriptionModel.rawValue
                    ])
                    self.captureState = .showingError
                    self.indicator.show(state: .error("No speech detected"))
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    self.indicator.hide()
                    return
                }
                self.lastCapture.set(text, autoClearAfter: TimeInterval(self.settings.copyLastTranscriptClearsAfterMinutes * 60))
                self.cursorIndicator.hideImmediately()
                if self.settings.outputMode == .clipboardPaste {
                    self.permissions.refreshStatuses()
                    if self.permissions.accessibilityEnabled {
                        self.output.pastePreservingClipboard(text, targetApplication: targetApplication)
                    } else {
                        self.output.copyToClipboard(text)
                        let decision = self.permissions.explainPasteAccessibilityAndChoose()
                        if decision == .useClipboardOnly {
                            self.settings.outputMode = .copyOnly
                        }
                        self.telemetry.captureError(.pastePermissionNeeded, properties: [
                            "output_mode": self.settings.outputMode.rawValue,
                            "decision": String(describing: decision)
                        ])
                        self.captureState = .showingError
                        self.indicator.show(state: .error(decision == .openSettings ? "Paste permission needed" : "Copied to clipboard"))
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                    }
                } else {
                    self.output.copyToClipboard(text)
                }
                self.telemetry.capture(.transcriptionSucceeded, properties: [
                    "recording_duration": recordingDurationBucket,
                    "transcript_length": self.lengthBucket(text.count),
                    "model": self.settings.transcriptionModel.rawValue,
                    "output_mode": self.settings.outputMode.rawValue
                ])
                _ = text.count // avoid logging sensitive content
            } catch is CancellationError {
                AppCoordinator.logger.info("Transcription flow cancelled")
                self.telemetry.capture(.recordingCancelled, properties: [
                    "phase": "transcription",
                    "recording_duration": recordingDurationBucket
                ])
                self.indicator.show(state: .error("Cancelled"))
                try? await Task.sleep(nanoseconds: 450_000_000)
            } catch {
                AppCoordinator.logger.error("Transcription error: \(String(describing: error), privacy: .public)")
                self.telemetry.captureError(.transcriptionFailed, properties: [
                    "recording_duration": recordingDurationBucket,
                    "model": self.settings.transcriptionModel.rawValue
                ])
                self.captureState = .showingError
                self.indicator.show(state: .error("Transcription failed"))
            }
            AppCoordinator.logger.info("Indicator hide; transcription flow complete")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self.indicator.hide()
        }
    }

    private func cancelCurrentCapture() {
        guard captureState.isRecording || transcriptionTask != nil else { return }

        AppCoordinator.logger.info("Cancelling current capture")
        shouldCancelCurrentCapture = true
        stopMeteringIndicator()

        if captureState.isRecording {
            let url = recorder.stop()
            if let url {
                try? FileManager.default.removeItem(at: url)
            }
            telemetry.capture(.recordingCancelled, properties: [
                "phase": "recording",
                "recording_duration": durationBucket(since: recordingStartedAt)
            ])
            recordingStartedAt = nil
            isPTTDown = false
            targetApplication = nil
            captureState = .idle
            cursorIndicator.hide()
            indicator.show(state: .error("Cancelled"))
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                self?.indicator.hide()
            }
            return
        }

        transcriptionTask?.cancel()
        if let activeRecordingURL {
            try? FileManager.default.removeItem(at: activeRecordingURL)
        }
        cursorIndicator.hide()
        indicator.show(state: .error("Cancelled"))
    }

    private func durationBucket(since startDate: Date?) -> String {
        guard let startDate else { return "unknown" }
        let duration = Date().timeIntervalSince(startDate)
        switch duration {
        case ..<1:
            return "<1s"
        case ..<3:
            return "1-3s"
        case ..<10:
            return "3-10s"
        case ..<30:
            return "10-30s"
        default:
            return "30s+"
        }
    }

    private func lengthBucket(_ characterCount: Int) -> String {
        switch characterCount {
        case ..<20:
            return "<20"
        case ..<100:
            return "20-99"
        case ..<500:
            return "100-499"
        default:
            return "500+"
        }
    }

    private func startMeteringIndicator() {
        meteringTask?.cancel()
        indicator.show(state: .recording(level: recorder.currentLevel()))
        meteringTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.captureState.isRecording else { break }
                self.indicator.show(state: .recording(level: self.recorder.currentLevel()))
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func stopMeteringIndicator() {
        meteringTask?.cancel()
        meteringTask = nil
    }
}
