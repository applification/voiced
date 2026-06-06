enum IndicatorState {
    case recording(level: Double)
    case loadingModel(String)
    case transcribing
    case error(String)
}
