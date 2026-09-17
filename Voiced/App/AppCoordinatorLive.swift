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
    private let transcriptPanel = CursorTranscriptPanel()
    private let processor = TranscriptProcessingService()
    private var directSession: DirectDictationSession?
    private var insertionAnchor: DictationInsertionAnchor?
    private var recordingStartTask: Task<Void, Error>?
    private var captureID = UUID()
    private var latestLiveText = ""
    private var shouldCleanUp = false

    private static let logger = Logger(subsystem: "net.applification.voiced", category: "coordinator")

    private var captureState: CaptureState = .idle
    private var modelDownloadObserver: NSObjectProtocol?
    private var transcriptionTask: Task<Void, Never>?
    private var doubleShiftRecognizer = DoubleShiftGestureRecognizer()
    private var pushToTalk = PushToTalkHotkey()
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
            transcriber: TranscriptionRouter(settings: settings),
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
        switch pushToTalk.register(type: type, keyCode: keyCode, flags: flags) {
        case .pressed:
            doubleShiftRecognizer.reset()
            activeVoiceDestination = VoiceCaptureDestination.resolve(from: flags)
            liveSession.pressPushToTalk()
            handleVoiceKeyDown()
            return
        case .released:
            doubleShiftRecognizer.reset()
            handleVoiceKeyUp()
            return
        case nil:
            break
        }

        if type == .keyDown {
            if keyCode == 53 {
                cancelCurrentCapture()
                return
            }
            if keyCode == 49, !pushToTalk.isHoldingSpace,
               flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift]) == .maskAlternate {
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

    }

    private func warmUpTranscriptionService(reason: String) {
        guard settings.modelDownloadsApproved, !captureState.isBusy,
              !transcriber.isSelectedModelLoaded else { return }
        captureState = .loadingModel
        if reason == "hotkey" { indicator.show(state: .processing) }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.transcriber.loadModelIfNeeded()
            } catch {
                Self.logger.error("Transcription model preparation failed")
                NotificationCenter.default.post(name: .voicedModelStatusChanged, object: self.settings.transcriptionModel)
                if reason != "app start" && reason != "onboarding download" {
                    self.indicator.show(state: .error("Model load failed"))
                    try? await Task.sleep(for: .milliseconds(650))
                }
            }
            self.captureState = .idle
            self.indicator.hide()
        }
    }

    private func handleModelProgress(_ progress: ModelLoadProgress) {
        NotificationCenter.default.post(name: .voicedModelProgressChanged, object: progress)
    }

    private func handleVoiceKeyDown() {
        if captureState.isShowingModelProgress {
            indicator.show(state: .processing)
            liveSession.reset()
            return
        }
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
        let application = contextTracker.runningApplication(for: activeVoiceContext)
        insertionAnchor = DictationInsertionAnchor(application: application)
        directSession = nil
        if settings.dictationMode == .direct, activeVoiceDestination == .focusedEditor,
           let target = AccessibilityTextTarget(application: application) {
            directSession = DirectDictationSession(target: target)
        }
        shouldCleanUp = settings.cleanUpAfterDictation
        latestLiveText = ""
        let id = UUID()
        captureID = id
        liveSession.beginRecording()
        soundCues.playActivation()
        captureState = .recording
        let status = activeVoiceDestination == .shelf ? "Listening · Save to Inbox"
            : directSession != nil ? "Listening · Direct" : "Listening · Preview"
        transcriptPanel.show(status: status) { [weak self] in self?.cancelCurrentCapture() }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            try Task.checkCancellation()
            try await self.transcriber.startLiveTranscription { [weak self] state in
                guard let self, self.captureID == id, self.captureState.isRecording else { return }
                self.latestLiveText = state.combinedText
                self.transcriptPanel.update(state)
                if !state.combinedText.isEmpty, let direct = self.directSession,
                   !direct.update(state.combinedText) {
                    self.transcriptPanel.setStatus("Preview · Field changed")
                }
            } onAudioLevel: { [weak self] level in
                guard let self, self.captureID == id, self.captureState.isRecording else { return }
                self.transcriptPanel.updateLevel(level)
            }
        }
        recordingStartTask = task
        Task { @MainActor [weak self] in
            guard case .failure = await task.result, let self,
                  self.captureID == id, self.captureState.isRecording else { return }
            self.captureState = .showingError
            await self.transcriber.cancelLiveTranscription()
            self.transcriptPanel.hide()
            self.showTemporaryIndicator(.error("Recording failed"))
            self.captureState = .idle
            self.recordingStartTask = nil
            self.liveSession.reset()
        }
    }

    private func handleVoiceKeyUp() {
        guard captureState.isRecording else { return }
        soundCues.playDeactivation()
        _ = liveSession.releasePushToTalk()
        captureState = .transcribing
        transcriptPanel.setStatus("Finishing transcription…")
        let id = captureID
        let startTask = recordingStartTask
        let sourceContext = activeVoiceContext
        let destination = activeVoiceDestination
        let direct = directSession
        let anchor = insertionAnchor
        let cleanup = shouldCleanUp
        activeVoiceContext = nil
        activeVoiceDestination = .focusedEditor
        transcriptionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var retainPanel = false
            defer {
                if self.captureID == id {
                    self.captureState = .idle
                    self.transcriptionTask = nil
                    self.recordingStartTask = nil
                    self.directSession = nil
                    self.liveSession.reset()
                    if !retainPanel { self.transcriptPanel.hide() }
                }
            }
            do {
                // A quick key release must wait for microphone setup before stopping it.
                try await startTask?.value
                let rawText = try await self.transcriber.stopLiveTranscription()
                try Task.checkCancellation()
                guard self.captureID == id else { return }
                guard let item = self.captures.add(text: rawText, source: .voice,
                                                   sourceApplication: sourceContext?.captureSource) else {
                    _ = direct?.cancel()
                    self.showTemporaryIndicator(.error("No speech detected"))
                    return
                }
                var finalText = item.text
                if cleanup, self.processor.availability.isAvailable {
                    self.transcriptPanel.setStatus("Cleaning up on this Mac…")
                    do {
                        let cleaned = try await self.processor.process(item.text, profile: .cleanTranscript)
                        try Task.checkCancellation()
                        if !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            finalText = cleaned
                            self.captures.applyRefinement(id: item.id, text: cleaned)
                        }
                    } catch is CancellationError { throw CancellationError() }
                    catch { /* The raw capture is already saved and remains the output. */ }
                }
                try Task.checkCancellation()
                guard self.captureID == id else { return }
                if destination == .shelf {
                    self.showTemporaryIndicator(.success("Saved to Inbox"))
                    return
                }
                let inserted: Bool
                if let direct {
                    inserted = direct.update(finalText)
                } else if anchor?.isUnchanged == true {
                    inserted = await self.output.insert(finalText,
                        into: self.contextTracker.runningApplication(for: sourceContext),
                        guardBeforePaste: { anchor?.isUnchanged == true }) == .inserted
                } else {
                    inserted = false
                }
                if inserted {
                    self.captures.move(id: item.id, to: .done)
                    self.showTemporaryIndicator(.success("Inserted"))
                } else {
                    // Never paste a second transcript after losing ownership of a direct draft.
                    retainPanel = true
                    self.transcriptPanel.retain(text: finalText, status: "Saved · Copy when ready") {
                        _ = self.output.copyToClipboard(finalText)
                    }
                }
            } catch is CancellationError {
                _ = direct?.cancel()
                self.showTemporaryIndicator(.error("Cancelled"))
            } catch {
                Self.logger.error("Transcription failed")
                _ = try? await self.transcriber.stopLiveTranscription()
                _ = direct?.cancel()
                if let partial = self.captures.add(text: self.latestLiveText, source: .voice,
                                                   sourceApplication: sourceContext?.captureSource) {
                    retainPanel = true
                    self.transcriptPanel.retain(text: partial.text, status: "Transcription failed · Partial saved") {
                        _ = self.output.copyToClipboard(partial.text)
                    }
                } else {
                    self.showTemporaryIndicator(.error("Transcription failed"))
                }
            }
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
        if let transcriptionTask {
            // The finalization task owns stopping and cancellation while finishing.
            transcriptionTask.cancel()
            transcriptPanel.setStatus("Cancelling…")
            return
        }
        _ = liveSession.cancelRecording()
        captureState = .transcribing
        transcriptPanel.setStatus("Cancelling…")
        let startTask = recordingStartTask
        let direct = directSession
        transcriptionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            _ = try? await startTask?.value
            await self.transcriber.cancelLiveTranscription()
            _ = direct?.cancel()
            self.transcriptPanel.hide()
            self.directSession = nil
            self.activeVoiceContext = nil
            self.recordingStartTask = nil
            self.transcriptionTask = nil
            self.captureState = .idle
            self.liveSession.reset()
            self.showTemporaryIndicator(.error("Cancelled"))
        }
    }
}

enum VoiceCaptureDestination: Equatable {
    case shelf
    case focusedEditor

    static func resolve(from flags: CGEventFlags) -> VoiceCaptureDestination {
        flags.contains(.maskAlternate) ? .shelf : .focusedEditor
    }
}
