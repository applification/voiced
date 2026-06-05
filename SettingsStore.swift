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

    var modelDownloadsApproved: Bool {
        didSet {
            userDefaults.set(modelDownloadsApproved, forKey: Keys.modelDownloadsApproved)
        }
    }

    var transcriptionModel: TranscriptionModel {
        didSet {
            userDefaults.set(transcriptionModel.rawValue, forKey: Keys.transcriptionModel)
        }
    }

    var launchAtLogin: Bool {
        didSet {
            userDefaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        }
    }

    var activationSound: SoundCue {
        didSet {
            userDefaults.set(activationSound.rawValue, forKey: Keys.activationSound)
        }
    }

    var deactivationSound: SoundCue {
        didSet {
            userDefaults.set(deactivationSound.rawValue, forKey: Keys.deactivationSound)
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

        modelDownloadsApproved = userDefaults.bool(forKey: Keys.modelDownloadsApproved)
            || userDefaults.bool(forKey: Keys.whisperTinyModelApproved)

        let storedModel = userDefaults.string(forKey: Keys.transcriptionModel)
            .flatMap(TranscriptionModel.init(rawValue:))
        transcriptionModel = storedModel ?? .tiny

        launchAtLogin = userDefaults.bool(forKey: Keys.launchAtLogin)

        let storedActivationSound = userDefaults.string(forKey: Keys.activationSound)
            .flatMap(SoundCue.init(rawValue:))
        activationSound = storedActivationSound ?? .pop

        let storedDeactivationSound = userDefaults.string(forKey: Keys.deactivationSound)
            .flatMap(SoundCue.init(rawValue:))
        deactivationSound = storedDeactivationSound ?? .tink
    }
}

enum TranscriptionModel: String, CaseIterable, Identifiable {
    case tiny
    case base
    case small
    case largeAccuracy = "large-v3-v20240930_626MB"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tiny: "Tiny"
        case .base: "Base"
        case .small: "Small"
        case .largeAccuracy: "Large v3"
        }
    }

    var detail: String {
        switch self {
        case .tiny: "Fastest"
        case .base: "Fast"
        case .small: "Balanced"
        case .largeAccuracy: "Most accurate"
        }
    }

    var menuTitle: String {
        "\(label) (\(detail))"
    }

    var cacheFolderName: String {
        "openai_whisper-\(rawValue)"
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

private enum Keys {
    static let outputMode = "outputMode"
    static let copyLastTranscriptClearsAfterMinutes = "copyLastTranscriptClearsAfterMinutes"
    static let modelDownloadsApproved = "modelDownloadsApproved"
    static let whisperTinyModelApproved = "whisperTinyModelApproved"
    static let transcriptionModel = "transcriptionModel"
    static let launchAtLogin = "launchAtLogin"
    static let activationSound = "activationSound"
    static let deactivationSound = "deactivationSound"
}
