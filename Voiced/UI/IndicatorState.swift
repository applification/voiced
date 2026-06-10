enum IndicatorState {
    case recording(level: Double)
    case transcribing
    case error(String)
}
