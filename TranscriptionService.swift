import Foundation

protocol TranscriptionService {
    func loadModelIfNeeded() async throws
    func transcribeFile(at url: URL) async throws -> String
}

final class PlaceholderTranscriptionService: TranscriptionService {
    func loadModelIfNeeded() async throws {
        // TODO: integrate WhisperKit model loading
    }

    func transcribeFile(at url: URL) async throws -> String {
        // TODO: integrate WhisperKit transcription
        // For now, return a stub to validate wiring
        return "[transcribed text stub]"
    }
}
