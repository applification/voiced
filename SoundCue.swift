enum SoundCue: String, CaseIterable, Identifiable {
    case none
    case basso = "Basso"
    case blow = "Blow"
    case bottle = "Bottle"
    case funk = "Funk"
    case glass = "Glass"
    case hero = "Hero"
    case morse = "Morse"
    case ping = "Ping"
    case pop = "Pop"
    case purr = "Purr"
    case sosumi = "Sosumi"
    case submarine = "Submarine"
    case tink = "Tink"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "None"
        default: rawValue
        }
    }

    var soundName: String? {
        switch self {
        case .none: nil
        default: rawValue
        }
    }
}
