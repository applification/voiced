import Foundation

/// Retains only one backend. A running session stays on the backend it started with.
@MainActor
final class TranscriptionRouter: AppTranscribing {
    private let settings: SettingsStore
    private var backend: (any AppTranscribing)?
    private var backendModel: TranscriptionModel?
    private var preparation: Task<Void, Error>?
    var onModelProgress: ((ModelLoadProgress) -> Void)?

    init(settings: SettingsStore) { self.settings = settings }

    var isSelectedModelLoaded: Bool {
        backendModel == settings.transcriptionModel && backend?.isSelectedModelLoaded == true
    }

    func loadModelIfNeeded() async throws {
        if let preparation { return try await preparation.value }
        let task = Task { @MainActor [self] in
            let selected = settings.transcriptionModel
            if backendModel != selected {
                backend = nil
                LoadedModelState.markUnloaded()
                backendModel = selected
                backend = selected == .parakeetV2
                    ? ParakeetTranscriptionService(settings: settings)
                    : WhisperKitTranscriptionService(settings: settings)
                backend?.onModelProgress = { [weak self] in self?.onModelProgress?($0) }
            }
            try await backend?.loadModelIfNeeded()
        }
        preparation = task
        defer { preparation = nil }
        try await task.value
    }

    func transcribeFile(at url: URL) async throws -> String {
        try await loadModelIfNeeded()
        guard let backend else { throw TranscriptionError.modelNotLoaded }
        return try await backend.transcribeFile(at: url)
    }

    func startLiveTranscription(
        onUpdate: @escaping @MainActor (LiveTranscriptState) -> Void,
        onAudioLevel: @escaping @MainActor (Double) -> Void
    ) async throws {
        guard let backend else { throw TranscriptionError.modelNotLoaded }
        try await backend.startLiveTranscription(onUpdate: onUpdate, onAudioLevel: onAudioLevel)
    }

    func cancelLiveTranscription() async { await backend?.cancelLiveTranscription() }

    func stopLiveTranscription() async throws -> String {
        try await backend?.stopLiveTranscription() ?? ""
    }
}
