enum IndicatorState {
    case recording(level: Double)
    case transcribing
    case processing
    case error(String)

    var isTextProgress: Bool {
        switch self {
        case .transcribing, .processing:
            true
        case .recording, .error:
            false
        }
    }

    var progressTitle: String {
        switch self {
        case .transcribing:
            "Transcribing"
        case .processing:
            "Processing"
        case .recording, .error:
            ""
        }
    }
}
