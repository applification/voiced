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

    var pushToTalkHotkey: PushToTalkHotkey {
        didSet {
            userDefaults.set(pushToTalkHotkey.rawValue, forKey: Keys.pushToTalkHotkey)
        }
    }

    var basicDiagnosticsEnabled: Bool {
        didSet {
            userDefaults.set(basicDiagnosticsEnabled, forKey: Keys.basicDiagnosticsEnabled)
        }
    }

    var hasSeenIntroOnboarding: Bool {
        didSet {
            userDefaults.set(hasSeenIntroOnboarding, forKey: Keys.hasSeenIntroOnboarding)
        }
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        let storedOutputMode = userDefaults.string(forKey: Keys.outputMode)
            .flatMap(OutputMode.init(rawValue:))
        outputMode = storedOutputMode ?? .clipboardPaste

        let storedClearMinutes = userDefaults.integer(forKey: Keys.copyLastTranscriptClearsAfterMinutes)
        copyLastTranscriptClearsAfterMinutes = Self.clampedLastCaptureMinutes(storedClearMinutes == 0 ? 3 : storedClearMinutes)

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

        let storedPushToTalkHotkey = userDefaults.string(forKey: Keys.pushToTalkHotkey)
            .flatMap(PushToTalkHotkey.init(rawValue:))
        pushToTalkHotkey = storedPushToTalkHotkey ?? .rightCommand

        if userDefaults.object(forKey: Keys.basicDiagnosticsEnabled) == nil {
            basicDiagnosticsEnabled = true
        } else {
            basicDiagnosticsEnabled = userDefaults.bool(forKey: Keys.basicDiagnosticsEnabled)
        }

        hasSeenIntroOnboarding = userDefaults.bool(forKey: Keys.hasSeenIntroOnboarding)
    }

    private static func clampedLastCaptureMinutes(_ minutes: Int) -> Int {
        min(max(minutes, 1), 5)
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
    static let pushToTalkHotkey = "pushToTalkHotkey"
    static let basicDiagnosticsEnabled = "basicDiagnosticsEnabled"
    static let hasSeenIntroOnboarding = "hasSeenIntroOnboarding"
}
