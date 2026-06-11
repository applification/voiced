enum IndicatorState {
    case recording(level: Double)
    case transcribing
    case processing
    case success(String)
    case error(String)

    var isTextProgress: Bool {
        switch self {
        case .transcribing, .processing:
            true
        case .recording, .success, .error:
            false
        }
    }

    var progressTitle: String {
        switch self {
        case .transcribing:
            "Transcribing"
        case .processing:
            "Processing"
        case .recording, .success, .error:
            ""
        }
    }
}
