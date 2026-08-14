import AppKit
import Foundation
import os

@MainActor
final class AppCoordinator {
    private let settings: SettingsStore
    private let hotkeys: any HotkeyListening
    private var transcriber: any AppTranscribing
    private let output: any OutputPerforming
    private let captures: CaptureStore
    private let contextTracker: ApplicationContextTracker
    private let selectedTextCapture: any SelectedTextCapturing
    private let indicator: any IndicatorPresenting
    private let microphonePermissions: any MicrophonePermissionManaging
    private let soundCues: any SoundCuePlaying
    private let liveSession = LiveDictationSession()

    private static let logger = Logger(subsystem: "net.applification.voiced", category: "coordinator")

    private var captureState: CaptureState = .idle
    private var modelDownloadObserver: NSObjectProtocol?
    private var transcriptionTask: Task<Void, Never>?
    private var doubleShiftRecognizer = DoubleShiftGestureRecognizer()
    private var isRightCommandPhysicallyDown = false
    private var lastShelfToggleTime: TimeInterval = 0
    private var activeVoiceContext: DestinationApplicationContext?
    private var activeVoiceDestination: VoiceCaptureDestination = .focusedEditor

    init(
        settings: SettingsStore,
        hotkeys: any HotkeyListening = HotkeyManager(),
        transcriber: any AppTranscribing,
        output: any OutputPerforming = OutputManager(),
        captures: CaptureStore,
        contextTracker: ApplicationContextTracker,
        selectedTextCapture: any SelectedTextCapturing = SelectedTextCaptureService(),
        indicator: any IndicatorPresenting = FloatingIndicator(),
        microphonePermissions: any MicrophonePermissionManaging = MicrophonePermissionManager(),
        soundCues: any SoundCuePlaying
    ) {
        self.settings = settings
        self.hotkeys = hotkeys
        self.transcriber = transcriber
        self.output = output
        self.captures = captures
        self.contextTracker = contextTracker
        self.selectedTextCapture = selectedTextCapture
        self.indicator = indicator
        self.microphonePermissions = microphonePermissions
        self.soundCues = soundCues
    }

    convenience init(
        settings: SettingsStore,
        captures: CaptureStore,
        contextTracker: ApplicationContextTracker,
        output: any OutputPerforming = OutputManager()
    ) {
        self.init(
            settings: settings,
            transcriber: WhisperKitTranscriptionService(settings: settings),
            output: output,
            captures: captures,
            contextTracker: contextTracker,
            soundCues: SoundCuePlayer(settings: settings)
        )
    }

    func start() {
        microphonePermissions.refreshStatuses()
        modelDownloadObserver = NotificationCenter.default.addObserver(
            forName: .voicedModelDownloadRequested,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            let source = notification.userInfo?["source"] as? String
            Task { @MainActor in
                self?.warmUpTranscriptionService(
                    reason: source == "onboarding" ? "onboarding download" : "download request"
                )
            }
        }
        transcriber.onModelProgress = { [weak self] progress in
            self?.handleModelProgress(progress)
        }
        hotkeys.startListening { [weak self] type, keyCode, flags in
            self?.handleGlobalInput(type: type, keyCode: keyCode, flags: flags)
        }

        if !IntroOnboardingPresenter.isSetupRequired(settings: settings) {
            warmUpTranscriptionService(reason: "app start")
        }
    }

    private func handleGlobalInput(type: CGEventType, keyCode: CGKeyCode, flags: CGEventFlags) {
        if type == .keyDown {
            if keyCode == 53 {
                cancelCurrentCapture()
                return
            }
            if keyCode == 49, flags.contains(.maskAlternate) {
                let now = ProcessInfo.processInfo.systemUptime
                guard now - lastShelfToggleTime > 0.30 else { return }
                lastShelfToggleTime = now
                _ = contextTracker.rememberFrontmostExternalApplication()
                NotificationCenter.default.post(name: .voicedShelfToggleRequested, object: nil)
            }
            return
        }

        guard type == .flagsChanged else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let hasOtherModifiers = flags.contains(.maskCommand)
            || flags.contains(.maskAlternate)
            || flags.contains(.maskControl)
        if doubleShiftRecognizer.register(
            keyCode: keyCode,
            isPressed: flags.contains(.maskShift),
            hasOtherModifiers: hasOtherModifiers,
            timestamp: now
        ) {
            captureSelectedText()
            return
        }

        let pushToTalk = PushToTalkHotkey.rightCommand
        guard keyCode == pushToTalk.keyCode else { return }
        isRightCommandPhysicallyDown.toggle()
        if isRightCommandPhysicallyDown {
            activeVoiceDestination = VoiceCaptureDestination.resolve(from: flags)
            liveSession.pressPushToTalk()
            handleVoiceKeyDown()
        } else {
            handleVoiceKeyUp()
        }
    }

    private func warmUpTranscriptionService(reason: String) {
        guard settings.modelDownloadsApproved else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let blocksCapture = !self.transcriber.isSelectedModelLoaded
            let shouldShowFailure = reason != "app start" && reason != "onboarding download"
            if blocksCapture { self.captureState = .loadingModel }
            do {
                try await self.transcriber.loadModelIfNeeded()
            } catch {
                Self.logger.error("Transcription model preparation failed")
                NotificationCenter.default.post(name: .voicedModelStatusChanged, object: self.settings.transcriptionModel)
                if blocksCapture, shouldShowFailure {
                    self.indicator.show(state: .error("Model load failed"))
                }
            }
            if blocksCapture {
                self.captureState = .idle
                try? await Task.sleep(for: .milliseconds(650))
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

    private func handleVoiceKeyDown() {
        guard settings.hasSeenIntroOnboarding, !captureState.isBusy else {
            liveSession.reset()
            return
        }
        microphonePermissions.refreshStatuses()
        guard microphonePermissions.micAuthorized else {
            showTemporaryIndicator(.error("Microphone access needed"), duration: 1_800_000_000)
            microphonePermissions.requestMicrophone { [weak self] _ in
                Task { @MainActor in self?.microphonePermissions.refreshStatuses() }
            }
            liveSession.reset()
            return
        }
        guard transcriber.isSelectedModelLoaded else {
            warmUpTranscriptionService(reason: "hotkey")
            liveSession.reset()
            return
        }

        activeVoiceContext = contextTracker.rememberFrontmostExternalApplication()
        liveSession.beginRecording()
        soundCues.playActivation()
        captureState = .recording
        indicator.show(state: .recording(level: 0.5))

        transcriptionTask?.cancel()
        transcriptionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.transcriber.startLiveTranscription { _ in
                } onAudioLevel: { [weak self] level in
                    self?.indicator.updateAudioLevel(level)
                }
                guard !self.liveSession.shouldCancel else { throw CancellationError() }
            } catch is CancellationError {
            } catch {
                Self.logger.error("Recording start failed")
                self.captureState = .showingError
                self.indicator.show(state: .error("Recording failed"))
                try? await Task.sleep(for: .seconds(1))
                self.indicator.hide()
                self.captureState = .idle
                self.transcriptionTask = nil
                self.liveSession.reset()
            }
        }
    }

    private func handleVoiceKeyUp() {
        guard captureState.isRecording else {
            liveSession.reset()
            return
        }
        soundCues.playDeactivation()
        _ = liveSession.releasePushToTalk()
        captureState = .transcribing
        indicator.show(state: .transcribing)

        let sourceContext = activeVoiceContext
        let destination = activeVoiceDestination
        activeVoiceContext = nil
        activeVoiceDestination = .focusedEditor
        transcriptionTask?.cancel()
        transcriptionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var feedbackDuration: UInt64 = 1_000_000_000
            defer {
                self.captureState = .idle
                self.transcriptionTask = nil
                self.liveSession.resetCancellation()
            }
            do {
                let text = await self.transcriber.stopLiveTranscription()
                try Task.checkCancellation()
                guard !self.liveSession.shouldCancel else { throw CancellationError() }
                guard let item = self.captures.add(
                    text: text,
                    source: .voice,
                    sourceApplication: sourceContext?.captureSource
                ) else {
                    self.showTemporaryIndicator(.error("No speech detected"))
                    return
                }
                switch destination {
                case .shelf:
                    self.indicator.show(state: .success("Saved to Inbox"))
                case .focusedEditor:
                    let result = await self.output.insert(
                        item.text,
                        into: self.contextTracker.runningApplication(for: sourceContext)
                    )
                    if result == .inserted {
                        self.captures.move(id: item.id, to: .done)
                        self.indicator.show(state: .success("Inserted"))
                    } else {
                        feedbackDuration = 2_000_000_000
                        let message = result == .accessibilityRequired
                            ? "Saved · Access needed"
                            : "Saved · Insert failed"
                        self.indicator.show(state: .error(message))
                    }
                }
            } catch is CancellationError {
                _ = await self.transcriber.stopLiveTranscription()
                self.indicator.show(state: .error("Cancelled"))
            } catch {
                Self.logger.error("Transcription failed")
                _ = await self.transcriber.stopLiveTranscription()
                self.indicator.show(state: .error("Transcription failed"))
            }
            try? await Task.sleep(nanoseconds: feedbackDuration)
            self.indicator.hide()
        }
    }

    private func captureSelectedText() {
        guard settings.hasSeenIntroOnboarding else { return }
        guard let context = contextTracker.rememberFrontmostExternalApplication() else {
            showTemporaryIndicator(.error("No source app"))
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let result = try await self.selectedTextCapture.capture(from: context)
                guard self.captures.add(
                    text: result.text,
                    source: .selection,
                    sourceApplication: result.sourceApplication
                ) != nil else {
                    self.showTemporaryIndicator(.error("No text selected"))
                    return
                }
                self.showTemporaryIndicator(.success("Selection captured"))
            } catch SelectedTextCaptureError.accessibilityRequired {
                self.showTemporaryIndicator(.error("Accessibility needed"), duration: 1_500_000_000)
            } catch SelectedTextCaptureError.noSelection {
                self.showTemporaryIndicator(.error("No text selected"))
            } catch {
                self.showTemporaryIndicator(.error("Selection capture failed"))
            }
        }
    }

    private func showTemporaryIndicator(_ state: IndicatorState, duration: UInt64 = 1_000_000_000) {
        indicator.show(state: state)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: duration)
            self?.indicator.hide()
        }
    }

    private func cancelCurrentCapture() {
        guard captureState.isRecording || transcriptionTask != nil else { return }
        _ = liveSession.cancelRecording()
        transcriptionTask?.cancel()
        transcriptionTask = nil
        activeVoiceContext = nil
        captureState = .transcribing
        indicator.show(state: .error("Cancelled"))
        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await self.transcriber.stopLiveTranscription()
            self.captureState = .idle
            self.liveSession.resetCancellation()
            try? await Task.sleep(for: .milliseconds(450))
            self.indicator.hide()
        }
    }
}

enum VoiceCaptureDestination: Equatable {
    case shelf
    case focusedEditor

    static func resolve(from flags: CGEventFlags) -> VoiceCaptureDestination {
        flags.contains(.maskShift) ? .shelf : .focusedEditor
    }
}
