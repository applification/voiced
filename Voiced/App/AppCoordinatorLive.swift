import Foundation
import AppKit
import os

@MainActor
final class AppCoordinator {
    private let settings: SettingsStore
    private let hotkeys: any HotkeyListening
    private var transcriber: any AppTranscribing
    private let output: any OutputPerforming
    private let indicator: any IndicatorPresenting
    private let cursorIndicator: any CursorIndicatorPresenting
    private let permissions: any MicrophonePermissionManaging
    private let soundCues: any SoundCuePlaying
    private let telemetry: any TelemetryReporting
    private let liveSession = LiveDictationSession()
    
    private static let logger = Logger(subsystem: "net.applification.voiced", category: "coordinator")

    private var captureState: CaptureState = .idle
    private var modelDownloadObserver: NSObjectProtocol?
    private var transcriptionTask: Task<Void, Never>?

    init(
        settings: SettingsStore,
        hotkeys: any HotkeyListening = HotkeyManager(),
        transcriber: any AppTranscribing,
        output: any OutputPerforming = OutputManager(),
        indicator: any IndicatorPresenting = FloatingIndicator(),
        cursorIndicator: any CursorIndicatorPresenting = CursorMicroIndicator(),
        permissions: any MicrophonePermissionManaging = MicrophonePermissionManager(),
        soundCues: any SoundCuePlaying,
        telemetry: any TelemetryReporting = TelemetryService()
    ) {
        self.settings = settings
        self.hotkeys = hotkeys
        self.transcriber = transcriber
        self.output = output
        self.indicator = indicator
        self.cursorIndicator = cursorIndicator
        self.permissions = permissions
        self.soundCues = soundCues
        self.telemetry = telemetry
    }

    convenience init(settings: SettingsStore, telemetry: any TelemetryReporting = TelemetryService()) {
        self.init(
            settings: settings,
            transcriber: WhisperKitTranscriptionService(settings: settings),
            soundCues: SoundCuePlayer(settings: settings),
            telemetry: telemetry
        )
    }

    func start() {
        permissions.refreshStatuses()
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
                let hotkey = self.settings.pushToTalkHotkey
                guard keyCode == hotkey.keyCode else { return }
                let isDown = flags.contains(hotkey.eventFlag)
                if isDown && !self.liveSession.isPushToTalkDown {
                    self.liveSession.pressPushToTalk()
                    self.handleKeyDown()
                } else if isDown && self.liveSession.isPushToTalkDown && !self.captureState.isRecording && !self.captureState.isBusy {
                    AppCoordinator.logger.warning("Push-to-talk latch was already down while idle; treating modifier event as a fresh press")
                    self.handleKeyDown()
                }
                if !isDown && self.liveSession.isPushToTalkDown { self.handleKeyUp() }
            default:
                break
            }
        }

        if !IntroOnboardingPresenter.isSetupRequired(settings: settings) {
            warmUpTranscriptionService(reason: "app start")
        }
    }

    private func warmUpTranscriptionService(reason: String) {
        guard settings.modelDownloadsApproved else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let shouldBlockCapture = !self.transcriber.isSelectedModelLoaded
            let shouldShowFailure = reason != "app start" && reason != "onboarding download"
            if shouldBlockCapture {
                self.captureState = .loadingModel
            }
            do {
                self.telemetry.capture(.modelLoadStarted, properties: [
                    "reason": reason,
                    "model": self.settings.transcriptionModel.rawValue
                ])
                try await self.transcriber.loadModelIfNeeded()
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
                if shouldBlockCapture && shouldShowFailure {
                    self.captureState = .showingError
                    self.indicator.show(state: .error("Model load failed"))
                }
            }
            if shouldBlockCapture {
                self.captureState = .idle
                try? await Task.sleep(nanoseconds: 650_000_000)
                self.indicator.hide()
            }
        }
    }

    private func handleModelProgress(_ progress: ModelLoadProgress) {
        NotificationCenter.default.post(name: .voicedModelProgressChanged, object: progress)
        guard progress.model == settings.transcriptionModel else { return }
        if progress.phase == "Loaded", captureState.isShowingModelProgress {
            captureState = .idle
        }
    }

    private func handleKeyDown() {
        guard settings.hasSeenIntroOnboarding else {
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

        guard transcriber.isSelectedModelLoaded else {
            warmUpTranscriptionService(reason: "hotkey")
            return
        }

        liveSession.beginRecording()
        soundCues.playActivation()
        captureState = .recording
        indicator.show(state: .recording(level: 0.5))

        telemetry.capture(.recordingStarted, properties: [
            "model": settings.transcriptionModel.rawValue,
            "output_mode": "review",
            "mode": "live"
        ])

        transcriptionTask?.cancel()
        transcriptionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                self.telemetry.capture(.modelLoadStarted, properties: [
                    "reason": "live_transcription",
                    "model": self.settings.transcriptionModel.rawValue
                ])
                try await self.transcriber.startLiveTranscription { [weak self] state in
                    guard let self else { return }
                    self.cursorIndicator.updateLiveTranscript(state)
                }
                self.telemetry.capture(.modelLoadSucceeded, properties: [
                    "reason": "live_transcription",
                    "model": self.settings.transcriptionModel.rawValue
                ])
                guard !self.liveSession.shouldCancel else { throw CancellationError() }
                self.captureState = .recording
                self.indicator.show(state: .recording(level: 0.5))
                self.cursorIndicator.showLiveTranscriptAtCursor(
                    state: LiveTranscriptState(committedText: "", provisionalText: "Listening...", isRecording: true)
                ) { [weak self] in
                    self?.cancelCurrentCapture()
                }
            } catch is CancellationError {
            } catch {
                AppCoordinator.logger.error("Failed to start live transcription: \(String(describing: error), privacy: .public)")
                self.telemetry.captureError(.recordingStartFailed, properties: [
                    "mode": "live",
                    "model": self.settings.transcriptionModel.rawValue
                ])
                self.captureState = .showingError
                self.cursorIndicator.hide()
                self.indicator.show(state: .error("Recording failed"))
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.indicator.hide()
                self.captureState = .idle
                self.transcriptionTask = nil
                self.liveSession.resetCancellation()
            }
        }
    }

    private func handleKeyUp() {
        guard captureState.isRecording else { return }
        soundCues.playDeactivation()
        let recordingDurationBucket = liveSession.releasePushToTalk()
        captureState = .transcribing
        indicator.show(state: .transcribing)

        transcriptionTask?.cancel()
        transcriptionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.captureState = .idle
                self.transcriptionTask = nil
                self.liveSession.resetCancellation()
            }
            do {
                let text = await self.transcriber.stopLiveTranscription()
                try Task.checkCancellation()
                guard !self.liveSession.shouldCancel else { throw CancellationError() }
                guard !text.isEmpty else {
                    AppCoordinator.logger.warning("Live transcription returned empty text")
                    self.telemetry.captureError(.transcriptionFailed, properties: [
                        "reason": "empty_text",
                        "recording_duration": recordingDurationBucket,
                        "model": self.settings.transcriptionModel.rawValue
                    ])
                    if self.cursorIndicator.hasReviewText {
                        self.cursorIndicator.showReviewAtCursor(
                            text: "",
                            onCopy: { [weak self] updatedText in
                                self?.output.copyToClipboard(updatedText)
                            },
                            onDropRejected: { [weak self] in
                                self?.showDropRejectedIndicator()
                            }
                        )
                        self.indicator.hide()
                    } else {
                        self.captureState = .showingError
                        self.cursorIndicator.hide()
                        self.indicator.show(state: .error("No speech detected"))
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        self.indicator.hide()
                    }
                    return
                }

                self.cursorIndicator.showReviewAtCursor(
                    text: text,
                    onCopy: { [weak self] updatedText in
                        self?.output.copyToClipboard(updatedText)
                    },
                    onDropRejected: { [weak self] in
                        self?.showDropRejectedIndicator()
                    }
                )
                self.indicator.show(state: .error("Copied for review"))
                self.telemetry.capture(.transcriptionSucceeded, properties: [
                    "recording_duration": recordingDurationBucket,
                    "transcript_length": self.lengthBucket(text.count),
                    "model": self.settings.transcriptionModel.rawValue,
                    "output_mode": "review",
                    "mode": "live"
                ])
                _ = text.count // avoid logging sensitive content
            } catch is CancellationError {
                _ = await self.transcriber.stopLiveTranscription()
                self.cursorIndicator.hide()
                self.telemetry.capture(.recordingCancelled, properties: [
                    "phase": "transcription",
                    "recording_duration": recordingDurationBucket,
                    "mode": "live"
                ])
                self.indicator.show(state: .error("Cancelled"))
                try? await Task.sleep(nanoseconds: 450_000_000)
            } catch {
                AppCoordinator.logger.error("Live transcription error: \(String(describing: error), privacy: .public)")
                _ = await self.transcriber.stopLiveTranscription()
                self.cursorIndicator.hide()
                self.telemetry.captureError(.transcriptionFailed, properties: [
                    "recording_duration": recordingDurationBucket,
                    "model": self.settings.transcriptionModel.rawValue,
                    "mode": "live"
                ])
                self.captureState = .showingError
                self.indicator.show(state: .error("Transcription failed"))
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self.indicator.hide()
        }
    }

    private func showDropRejectedIndicator() {
        indicator.show(state: .error("Drop not accepted. Press ⌘V"))
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self?.indicator.hide()
        }
    }

    private func cancelCurrentCapture() {
        guard captureState.isRecording || captureState.isShowingModelProgress || transcriptionTask != nil else { return }

        let recordingDurationBucket = liveSession.cancelRecording()
        transcriptionTask?.cancel()
        transcriptionTask = nil
        captureState = .idle
        cursorIndicator.hide()
        indicator.show(state: .error("Cancelled"))
        telemetry.capture(.recordingCancelled, properties: [
            "phase": "recording",
            "recording_duration": recordingDurationBucket,
            "mode": "live"
        ])

        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await self.transcriber.stopLiveTranscription()
            try? await Task.sleep(nanoseconds: 450_000_000)
            self.indicator.hide()
            self.liveSession.resetCancellation()
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

}
