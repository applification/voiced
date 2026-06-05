import Foundation
import os
import WhisperKit

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
    private let loadTimeoutNanoseconds: UInt64 = 120_000_000_000

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
            let config = WhisperKitConfig(model: selectedModel.rawValue, prewarm: true)
            self.whisperKit = try await WhisperKit(config)
            self.loadedModel = selectedModel
        }
        loadTask = task
        do {
            try await waitForLoadTask(task, selectedModel: selectedModel)
            loadTask = nil
        } catch {
            loadTask = nil
            task.cancel()
            throw error
        }
        logger.info("WhisperKit model loaded: \(selectedModel.rawValue, privacy: .public)")
    }

    private func waitForLoadTask(_ task: Task<Void, Error>, selectedModel: TranscriptionModel) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await task.value
            }
            group.addTask { [loadTimeoutNanoseconds] in
                try await Task.sleep(nanoseconds: loadTimeoutNanoseconds)
                throw TranscriptionError.modelLoadTimedOut(selectedModel.label)
            }

            guard let result = try await group.next() else { return }
            group.cancelAll()
            return result
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
}

enum TranscriptionError: LocalizedError {
    case modelDownloadNotApproved(String)
    case modelNotLoaded
    case modelLoadTimedOut(String)
    case noResult

    var errorDescription: String? {
        switch self {
        case .modelDownloadNotApproved(let model):
            "WhisperKit model '\(model)' has not been approved for download/loading."
        case .modelNotLoaded:
            "WhisperKit model was not loaded."
        case .modelLoadTimedOut(let model):
            "WhisperKit model '\(model)' did not finish loading."
        case .noResult:
            "WhisperKit completed without returning a transcription result."
        }
    }
}
