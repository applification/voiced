enum CaptureState {
    case idle
    case recording
    case loadingModel
    case transcribing
    case showingError

    var isBusy: Bool {
        switch self {
        case .idle:
            false
        case .recording, .loadingModel, .transcribing, .showingError:
            true
        }
    }

    var isRecording: Bool {
        if case .recording = self {
            return true
        }
        return false
    }

    var isShowingModelProgress: Bool {
        if case .loadingModel = self {
            return true
        }
        return false
    }
}
