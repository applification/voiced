import Foundation

@MainActor
enum LoadedModelState {
    private(set) static var model: TranscriptionModel?

    static func markLoaded(_ loadedModel: TranscriptionModel) {
        model = loadedModel
    }

    static func markUnloaded() {
        model = nil
    }

    static func isLoaded(_ candidate: TranscriptionModel) -> Bool {
        model == candidate
    }
}
