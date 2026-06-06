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
    private let permissions: any PermissionManaging
    private let soundCues: any SoundCuePlaying
    
    private static let logger = Logger(subsystem: "net.applification.voiced", category: "coordinator")

    private var captureState: CaptureState = .idle
    private var targetApplication: NSRunningApplication?
    private var modelApprovalObserver: NSObjectProtocol?
    private var meteringTask: Task<Void, Never>?
    private var isPTTDown = false

    init(
        settings: SettingsStore,
        lastCapture: LastCaptureStore,
        hotkeys: any HotkeyListening = HotkeyManager(),
        recorder: any AudioRecording = AudioRecorder(),
        transcriber: any AppTranscribing,
        output: any OutputPerforming = OutputManager(),
        indicator: any IndicatorPresenting = FloatingIndicator(),
        permissions: any PermissionManaging = PermissionManager(),
        soundCues: any SoundCuePlaying
    ) {
        self.settings = settings
        self.lastCapture = lastCapture
        self.hotkeys = hotkeys
        self.recorder = recorder
        self.transcriber = transcriber
        self.output = output
        self.indicator = indicator
        self.permissions = permissions
        self.soundCues = soundCues
    }

    convenience init(settings: SettingsStore, lastCapture: LastCaptureStore) {
        self.init(
            settings: settings,
            lastCapture: lastCapture,
            transcriber: WhisperKitTranscriptionService(settings: settings),
            soundCues: SoundCuePlayer(settings: settings)
        )
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
        transcriber.onModelProgress = { [weak self] progress in
            self?.handleModelProgress(progress)
        }
        hotkeys.startListening { [weak self] (type: CGEventType, keyCode: CGKeyCode, flags: CGEventFlags) in
            guard let self else { return }
            switch type {
            case .flagsChanged:
                AppCoordinator.logger.debug("flagsChanged keyCode=\(keyCode, privacy: .public) flags=\(UInt64(flags.rawValue), privacy: .public)")
                let hotkey = self.settings.pushToTalkHotkey
                guard keyCode == hotkey.keyCode else { return }
                let isDown = flags.contains(hotkey.eventFlag)
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
                self.captureState = .loadingModel
                self.indicator.show(state: .loadingModel(self.settings.transcriptionModel.label))
            }
            do {
                AppCoordinator.logger.info("Warming transcription service; reason=\(reason, privacy: .public)")
                try await self.transcriber.loadModelIfNeeded()
                AppCoordinator.logger.info("Transcription service warm")
            } catch {
                AppCoordinator.logger.error("Transcription warm-up failed: \(String(describing: error), privacy: .public)")
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
        guard !captureState.isBusy else { return }
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
            lastCapture.clear()
            captureState = .recording
            soundCues.playActivation()
            startMeteringIndicator()
        } catch {
            AppCoordinator.logger.error("Failed to start recording: \(String(describing: error), privacy: .public)")
        }
    }

    private func handleKeyUp() {
        AppCoordinator.logger.debug("handleKeyUp() invoked; isRecording was true")
        guard captureState.isRecording else { return }
        soundCues.playDeactivation()
        stopMeteringIndicator()
        if transcriber.isSelectedModelLoaded {
            captureState = .transcribing
            indicator.show(state: .transcribing)
        } else {
            captureState = .loadingModel
            indicator.show(state: .loadingModel(settings.transcriptionModel.label))
        }
        let url = recorder.stop()
        let targetApplication = targetApplication
        self.targetApplication = nil
        AppCoordinator.logger.debug("Recorder stopped; url present=\(url != nil, privacy: .public)")
        guard let url else {
            captureState = .idle
            indicator.hide()
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.captureState = .idle
                try? FileManager.default.removeItem(at: url)
            }
            do {
                AppCoordinator.logger.info("Loading transcription service")
                try await self.transcriber.loadModelIfNeeded()
                self.captureState = .transcribing
                self.indicator.show(state: .transcribing)
                AppCoordinator.logger.info("Starting transcription for \(url.lastPathComponent, privacy: .public)")
                let text = try await self.transcriber.transcribeFile(at: url)
                AppCoordinator.logger.info("Transcription completed; characters=\(text.count, privacy: .public)")
                guard !text.isEmpty else {
                    AppCoordinator.logger.warning("Transcription returned empty text")
                    self.captureState = .showingError
                    self.indicator.show(state: .error("No speech detected"))
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    self.indicator.hide()
                    return
                }
                self.lastCapture.set(text, autoClearAfter: TimeInterval(self.settings.copyLastTranscriptClearsAfterMinutes * 60))
                if self.settings.outputMode == .clipboardPaste {
                    self.permissions.refreshStatuses()
                    if self.permissions.accessibilityEnabled {
                        self.output.pastePreservingClipboard(text, targetApplication: targetApplication)
                    } else {
                        self.permissions.openAccessibilityPrefs()
                        self.output.copyToClipboard(text)
                        self.captureState = .showingError
                        self.indicator.show(state: .error("Paste permission needed"))
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                    }
                } else {
                    self.output.copyToClipboard(text)
                }
                _ = text.count // avoid logging sensitive content
            } catch {
                AppCoordinator.logger.error("Transcription error: \(String(describing: error), privacy: .public)")
                self.captureState = .showingError
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
