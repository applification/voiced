import Foundation
import Observation

@Observable
final class SettingsStore {
    var outputMode: OutputMode {
        didSet {
            userDefaults.set(outputMode.rawValue, forKey: Keys.outputMode)
        }
    }

    var copyLastTranscriptClearsAfterMinutes: Int {
        didSet {
            userDefaults.set(copyLastTranscriptClearsAfterMinutes, forKey: Keys.copyLastTranscriptClearsAfterMinutes)
        }
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        let storedOutputMode = userDefaults.string(forKey: Keys.outputMode)
            .flatMap(OutputMode.init(rawValue:))
        outputMode = storedOutputMode ?? .clipboardPaste

        let storedClearMinutes = userDefaults.integer(forKey: Keys.copyLastTranscriptClearsAfterMinutes)
        copyLastTranscriptClearsAfterMinutes = storedClearMinutes == 0 ? 20 : storedClearMinutes
    }
}

enum OutputMode: String, CaseIterable, Identifiable {
    case clipboardPaste
    case copyOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .clipboardPaste:
            "Paste"
        case .copyOnly:
            "Copy"
        }
    }
}

private enum Keys {
    static let outputMode = "outputMode"
    static let copyLastTranscriptClearsAfterMinutes = "copyLastTranscriptClearsAfterMinutes"
}
