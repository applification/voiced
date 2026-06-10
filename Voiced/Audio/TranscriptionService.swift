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
        guard whisperKit == nil || loadedModel != selectedModel else { return }
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

        logger.info("Loading WhisperKit model: \(selectedModel.rawValue, privacy: .public)")
        let task = Task { @MainActor [selectedModel] in
            let modelFolder = try await self.resolveModelFolder(for: selectedModel)
            self.postModelProgress(model: selectedModel, phase: "Preparing", fractionCompleted: 1)
            let config = WhisperKitConfig(
                model: selectedModel.rawValue,
                modelFolder: modelFolder.path,
                computeOptions: selectedModel.modelComputeOptions,
                prewarm: false,
                load: false,
                download: false
            )
            let whisperKit = try await WhisperKit(config)
            whisperKit.modelStateCallback = { [weak self, selectedModel] _, newState in
                Task { @MainActor in
                    self?.logger.info("WhisperKit model state: \(newState.description, privacy: .public)")
                    self?.postModelProgress(model: selectedModel, phase: newState.description, fractionCompleted: 1)
                }
            }
            try await whisperKit.loadModels()
            self.whisperKit = whisperKit
            self.loadedModel = selectedModel
        }
        loadTask = task
        do {
            try await waitForPreparationTask(task, selectedModel: selectedModel)
            loadTask = nil
        } catch {
            loadTask = nil
            task.cancel()
            throw error
        }
        logger.info("WhisperKit model loaded: \(selectedModel.rawValue, privacy: .public)")
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

    private func resolveModelFolder(for selectedModel: TranscriptionModel) async throws -> URL {
        let store = ModelStore(model: selectedModel)
        if store.isPlausiblyComplete {
            try verifyDownloadedModel(store, selectedModel: selectedModel)
            postModelProgress(model: selectedModel, phase: "Downloaded", fractionCompleted: 1)
            return store.localModelURL
        }

        logger.info("Downloading WhisperKit model: \(selectedModel.rawValue, privacy: .public)")
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
                from: store.modelRepo
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.postModelProgress(
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
        logger.info("WhisperKit model downloaded: \(folder.path, privacy: .public)")
        postModelProgress(model: selectedModel, phase: "Downloaded", fractionCompleted: 1)
        return folder
    }

    private func verifyDownloadedModel(_ store: ModelStore, selectedModel: TranscriptionModel) throws {
        do {
            try ModelIntegrity.verify(model: selectedModel, at: store.localModelURL)
            logger.info("Verified WhisperKit model integrity: \(selectedModel.rawValue, privacy: .public)")
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
        logger.info("Starting WhisperKit transcription; file exists: \(FileManager.default.fileExists(atPath: path), privacy: .public)")
        let results = try await whisperKit.transcribe(audioPath: path)
        let text = results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw TranscriptionError.noResult
        }

        logger.info("WhisperKit transcription completed; characters=\(text.count, privacy: .public)")
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

        let transcriber = AudioStreamTranscriber(
            audioEncoder: whisperKit.audioEncoder,
            featureExtractor: whisperKit.featureExtractor,
            segmentSeeker: whisperKit.segmentSeeker,
            textDecoder: whisperKit.textDecoder,
            tokenizer: tokenizer,
            audioProcessor: whisperKit.audioProcessor,
            decodingOptions: DecodingOptions(),
            stateChangeCallback: { [weak self] _, newState in
                let committed = newState.confirmedSegments
                    .map(\.text)
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let unconfirmed = newState.unconfirmedSegments
                    .map(\.text)
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let current = newState.currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                let provisional = current.isEmpty ? unconfirmed : current
                let isRecording = newState.isRecording

                Task { @MainActor in
                    let state = LiveTranscriptState(
                        committedText: committed,
                        provisionalText: provisional,
                        isRecording: isRecording
                    )
                    self?.latestLiveState = state
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
        logger.info("Live transcription started")
    }

    func stopLiveTranscription() async -> String {
        guard let streamTranscriber else {
            return latestLiveState.combinedText
        }

        await streamTranscriber.stopStreamTranscription()
        streamTranscriptionTask?.cancel()
        streamTranscriptionTask = nil
        self.streamTranscriber = nil

        let text = latestLiveState.combinedText
        latestLiveState = .idle
        logger.info("Live transcription stopped; characters=\(text.count, privacy: .public)")
        return text
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
