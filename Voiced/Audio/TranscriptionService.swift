import CoreML
import Foundation
import os
@preconcurrency import WhisperKit

@MainActor
protocol TranscriptionService {
    func loadModelIfNeeded() async throws
    func transcribeFile(at url: URL) async throws -> String
}

@MainActor
final class WhisperKitTranscriptionService: TranscriptionService {
    private let logger = Logger(subsystem: "net.applification.voiced", category: "transcription")
    private let settings: SettingsStore
    private var whisperKit: WhisperKit?
    private var loadedModel: TranscriptionModel?
    private var loadTask: Task<Void, Error>?
    private var lastProgressByModel: [TranscriptionModel: Double] = [:]
    private var streamTranscriber: AudioStreamTranscriber?
    private var streamTranscriptionTask: Task<Void, Never>?
    private var latestLiveState = LiveTranscriptState.idle
    private var livePreviousWords: [WordTiming] = []
    private var liveConfirmedWords: [WordTiming] = []
    private let liveWordConfirmationsNeeded = 2
    private let liveStopGraceNanoseconds: UInt64 = 800_000_000
    private let liveFinalizationTimeoutNanoseconds: UInt64 = 1_500_000_000
    private let preparationTimeoutNanoseconds: UInt64 = 60_000_000_000
    var onModelProgress: ((ModelLoadProgress) -> Void)?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    var isSelectedModelLoaded: Bool {
        whisperKit != nil && loadedModel == settings.transcriptionModel
    }

    func loadModelIfNeeded() async throws {
        let selectedModel = settings.transcriptionModel
        guard whisperKit == nil || loadedModel != selectedModel else {
            LoadedModelState.markLoaded(selectedModel)
            postModelProgress(model: selectedModel, phase: "Loaded", fractionCompleted: 1)
            return
        }
        if let loadTask {
            try await loadTask.value
            guard loadedModel == selectedModel else {
                return try await loadModelIfNeeded()
            }
            return
        }
        guard settings.modelDownloadsApproved else {
            throw TranscriptionError.modelDownloadNotApproved(selectedModel.rawValue)
        }

        whisperKit = nil
        loadedModel = nil
        LoadedModelState.markUnloaded()

        let task = Task { @MainActor [selectedModel] in
            let store = ModelStore(model: selectedModel)
            let modelFolder = try await self.resolveModelFolder(for: selectedModel, store: store)
            self.postModelProgress(model: selectedModel, phase: "Preparing", fractionCompleted: 1)
            let config = WhisperKitConfig(
                model: selectedModel.rawValue,
                downloadBase: store.downloadBaseURL,
                modelFolder: modelFolder.path,
                tokenizerFolder: store.downloadBaseURL,
                computeOptions: selectedModel.modelComputeOptions,
                prewarm: false,
                load: false,
                download: false
            )
            let whisperKit = try await WhisperKit(config)
            whisperKit.modelStateCallback = { [selectedModel] _, newState in
                Task { @MainActor in
                    self.postModelProgress(model: selectedModel, phase: newState.description, fractionCompleted: 1)
                }
            }
            try await whisperKit.loadModels()
            self.whisperKit = whisperKit
            self.loadedModel = selectedModel
            LoadedModelState.markLoaded(selectedModel)
            self.postModelProgress(model: selectedModel, phase: "Loaded", fractionCompleted: 1)
        }
        loadTask = task
        do {
            try await waitForPreparationTask(task, selectedModel: selectedModel)
            loadTask = nil
        } catch {
            loadTask = nil
            task.cancel()
            LoadedModelState.markUnloaded()
            throw error
        }
    }

    private func waitForPreparationTask(_ task: Task<Void, Error>, selectedModel: TranscriptionModel) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await task.value
            }
            group.addTask { [preparationTimeoutNanoseconds] in
                try await Task.sleep(nanoseconds: preparationTimeoutNanoseconds)
                throw TranscriptionError.modelPreparationTimedOut(selectedModel.label)
            }

            guard let result = try await group.next() else { return }
            group.cancelAll()
            return result
        }
    }

    private func resolveModelFolder(for selectedModel: TranscriptionModel, store: ModelStore) async throws -> URL {
        try store.prepareStorageForDownload()
        if store.isPlausiblyComplete {
            try verifyDownloadedModel(store, selectedModel: selectedModel)
            postModelProgress(model: selectedModel, phase: "Downloaded", fractionCompleted: 1)
            return store.localModelURL
        }

        lastProgressByModel[selectedModel] = 0
        postModelProgress(model: selectedModel, phase: "Downloading", fractionCompleted: 0)
        let progressPollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.postModelProgressFromCacheSize(model: selectedModel, store: store)
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        let remoteDownloadTask = Task {
            try await WhisperKit.download(
                variant: selectedModel.rawValue,
                downloadBase: store.downloadBaseURL,
                from: store.modelRepo
            ) { progress in
                Task { @MainActor in
                    self.postModelProgress(
                        model: selectedModel,
                        phase: "Downloading",
                        fractionCompleted: progress.fractionCompleted
                    )
                }
            }
        }
        defer {
            progressPollingTask.cancel()
        }
        let folder = try await remoteDownloadTask.value
        try verifyDownloadedModel(store, selectedModel: selectedModel)
        postModelProgress(model: selectedModel, phase: "Downloaded", fractionCompleted: 1)
        return folder
    }

    private func verifyDownloadedModel(_ store: ModelStore, selectedModel: TranscriptionModel) throws {
        do {
            try ModelIntegrity.verify(model: selectedModel, at: store.localModelURL)
        } catch {
            logger.error("WhisperKit model integrity verification failed: \(String(describing: error), privacy: .public)")
            try? store.deleteDownloadedModel()
            throw TranscriptionError.modelIntegrityVerificationFailed(selectedModel.label)
        }
    }

    private func postModelProgressFromCacheSize(model: TranscriptionModel, store: ModelStore) {
        let expectedBytes = model.expectedDownloadBytes
        guard expectedBytes > 0 else { return }
        let bytes = store.downloadedBytes
        guard bytes > 0 else { return }
        let fraction = Double(min(bytes, expectedBytes)) / Double(expectedBytes)
        postModelProgress(model: model, phase: "Downloading", fractionCompleted: fraction)
    }

    private func postModelProgress(model: TranscriptionModel, phase: String, fractionCompleted: Double) {
        let clampedFraction = max(0, min(1, fractionCompleted))
        let displayedFraction: Double
        if phase == "Downloading" {
            let previous = lastProgressByModel[model] ?? 0
            displayedFraction = max(previous, clampedFraction)
            lastProgressByModel[model] = displayedFraction
        } else {
            displayedFraction = clampedFraction
            if phase == "Downloaded" || phase == "Preparing" {
                lastProgressByModel[model] = 1
            }
        }

        onModelProgress?(
            ModelLoadProgress(
                model: model,
                phase: phase,
                fractionCompleted: displayedFraction
            )
        )
        if phase == "Downloaded" || phase == "Loaded" {
            NotificationCenter.default.post(name: .voicedModelStatusChanged, object: model)
        }
    }

    func transcribeFile(at url: URL) async throws -> String {
        try await loadModelIfNeeded()
        guard let whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        let path = url.path
        let results = try await whisperKit.transcribe(audioPath: path)
        let text = LiveTranscriptState.sanitizedText(
            results
                .map(\.text)
                .joined(separator: " ")
        )
        guard !text.isEmpty else {
            throw TranscriptionError.noResult
        }

        return text
    }

    func startLiveTranscription(onUpdate: @escaping @MainActor (LiveTranscriptState) -> Void) async throws {
        try await loadModelIfNeeded()
        guard let whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }
        guard let tokenizer = whisperKit.tokenizer else {
            throw TranscriptionError.modelNotLoaded
        }

        await streamTranscriber?.stopStreamTranscription()
        streamTranscriptionTask?.cancel()
        latestLiveState = .idle
        livePreviousWords = []
        liveConfirmedWords = []

        nonisolated(unsafe) let audioEncoder = whisperKit.audioEncoder
        nonisolated(unsafe) let featureExtractor = whisperKit.featureExtractor
        nonisolated(unsafe) let segmentSeeker = whisperKit.segmentSeeker
        nonisolated(unsafe) let textDecoder = whisperKit.textDecoder
        nonisolated(unsafe) let streamTokenizer = tokenizer
        nonisolated(unsafe) let audioProcessor = whisperKit.audioProcessor

        let transcriber = AudioStreamTranscriber(
            audioEncoder: audioEncoder,
            featureExtractor: featureExtractor,
            segmentSeeker: segmentSeeker,
            textDecoder: textDecoder,
            tokenizer: streamTokenizer,
            audioProcessor: audioProcessor,
            decodingOptions: DecodingOptions(
                skipSpecialTokens: true,
                wordTimestamps: true
            ),
            requiredSegmentsForConfirmation: 1,
            stateChangeCallback: { [weak self] _, newState in
                let confirmedSegments = newState.confirmedSegments
                let unconfirmedSegments = newState.unconfirmedSegments
                let hypothesisWords = unconfirmedSegments.flatMap { $0.words ?? [] }
                let isRecording = newState.isRecording

                Task { @MainActor in
                    guard let self else { return }
                    let state = self.liveTranscriptState(
                        confirmedSegments: confirmedSegments,
                        unconfirmedSegments: unconfirmedSegments,
                        hypothesisWords: hypothesisWords,
                        isRecording: isRecording
                    )
                    self.latestLiveState = state
                    onUpdate(state)
                }
            }
        )
        streamTranscriber = transcriber
        streamTranscriptionTask = Task { [weak self, transcriber] in
            do {
                try await transcriber.startStreamTranscription()
            } catch {
                await MainActor.run {
                    self?.logger.error("Live transcription failed: \(String(describing: error), privacy: .public)")
                }
            }
        }
        onUpdate(LiveTranscriptState(committedText: "", provisionalText: "Listening...", isRecording: true))
    }

    func stopLiveTranscription() async -> String {
        guard let streamTranscriber else {
            return latestLiveState.combinedText
        }

        try? await Task.sleep(nanoseconds: liveStopGraceNanoseconds)
        await streamTranscriber.stopStreamTranscription()
        await waitForLiveStreamFinalization()
        streamTranscriptionTask?.cancel()
        streamTranscriptionTask = nil
        self.streamTranscriber = nil

        let text = latestLiveState.combinedText
        latestLiveState = .idle
        livePreviousWords = []
        liveConfirmedWords = []
        return text
    }

    private func waitForLiveStreamFinalization() async {
        guard let streamTranscriptionTask else { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await streamTranscriptionTask.value
            }
            group.addTask { [liveFinalizationTimeoutNanoseconds] in
                try? await Task.sleep(nanoseconds: liveFinalizationTimeoutNanoseconds)
            }
            await group.next()
            group.cancelAll()
        }
    }

    private func liveTranscriptState(
        confirmedSegments: [TranscriptionSegment],
        unconfirmedSegments: [TranscriptionSegment],
        hypothesisWords: [WordTiming],
        isRecording: Bool
    ) -> LiveTranscriptState {
        let shouldFinalizeProvisional = !isRecording
        if !confirmedSegments.isEmpty || hypothesisWords.isEmpty {
            livePreviousWords = []
            liveConfirmedWords = []
            let committed = LiveTranscriptState.sanitizedText(
                confirmedSegments
                    .map(\.text)
                    .joined(separator: " ")
            )
            let unconfirmed = LiveTranscriptState.sanitizedText(
                unconfirmedSegments
                    .map(\.text)
                    .joined(separator: " ")
            )
            if !shouldFinalizeProvisional {
                return LiveTranscriptState(
                    committedText: committed,
                    provisionalText: unconfirmed,
                    isRecording: isRecording
                )
            }
            return LiveTranscriptState(
                committedText: [committed, unconfirmed]
                    .filter { !$0.isEmpty }
                    .joined(separator: " "),
                provisionalText: "",
                isRecording: isRecording
            )
        }

        if !livePreviousWords.isEmpty {
            let commonPrefix = Self.longestCommonWordPrefix(livePreviousWords, hypothesisWords)
            let confirmedCount = max(0, commonPrefix.count - liveWordConfirmationsNeeded)
            if confirmedCount > liveConfirmedWords.count {
                liveConfirmedWords = Array(commonPrefix.prefix(confirmedCount))
            }
        }

        livePreviousWords = hypothesisWords

        let confirmedWordCount = min(liveConfirmedWords.count, hypothesisWords.count)
        let provisionalWords = Array(hypothesisWords.dropFirst(confirmedWordCount))
        let committed = Self.text(from: liveConfirmedWords)
        let provisional = Self.text(from: provisionalWords)
        if !shouldFinalizeProvisional {
            return LiveTranscriptState(
                committedText: committed,
                provisionalText: provisional,
                isRecording: isRecording
            )
        }
        return LiveTranscriptState(
            committedText: [committed, provisional]
                .filter { !$0.isEmpty }
                .joined(separator: " "),
            provisionalText: "",
            isRecording: isRecording
        )
    }

    private nonisolated static func longestCommonWordPrefix(_ lhs: [WordTiming], _ rhs: [WordTiming]) -> [WordTiming] {
        let count = min(lhs.count, rhs.count)
        var prefix: [WordTiming] = []
        for index in 0..<count {
            guard wordsMatch(lhs[index], rhs[index]) else { break }
            prefix.append(rhs[index])
        }
        return prefix
    }

    private nonisolated static func wordsMatch(_ lhs: WordTiming, _ rhs: WordTiming) -> Bool {
        lhs.tokens == rhs.tokens && lhs.word.trimmingCharacters(in: .whitespacesAndNewlines) == rhs.word.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func text(from words: [WordTiming]) -> String {
        LiveTranscriptState.sanitizedText(words.map(\.word).joined())
    }


}

enum TranscriptionError: LocalizedError {
    case modelDownloadNotApproved(String)
    case modelIntegrityVerificationFailed(String)
    case modelNotLoaded
    case modelPreparationTimedOut(String)
    case noResult

    var errorDescription: String? {
        switch self {
        case .modelDownloadNotApproved(let model):
            "WhisperKit model '\(model)' has not been approved for download/loading."
        case .modelIntegrityVerificationFailed(let model):
            "WhisperKit model '\(model)' failed integrity verification and was removed."
        case .modelNotLoaded:
            "WhisperKit model was not loaded."
        case .modelPreparationTimedOut(let model):
            "WhisperKit model '\(model)' did not finish preparing."
        case .noResult:
            "WhisperKit completed without returning a transcription result."
        }
    }
}
