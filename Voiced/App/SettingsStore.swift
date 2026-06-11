import Foundation
import Observation

@Observable
final class SettingsStore {
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

    var transcriptProcessingProfile: TranscriptProcessingProfile {
        didSet {
            userDefaults.set(transcriptProcessingProfile.rawValue, forKey: Keys.transcriptProcessingProfile)
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

        modelDownloadsApproved = userDefaults.bool(forKey: Keys.modelDownloadsApproved)
            || userDefaults.bool(forKey: Keys.whisperTinyModelApproved)

        let storedModel = userDefaults.string(forKey: Keys.transcriptionModel)
            .flatMap(TranscriptionModel.init(rawValue:))
        transcriptionModel = storedModel ?? .tiny

        launchAtLogin = userDefaults.bool(forKey: Keys.launchAtLogin)

        let storedTranscriptProcessingProfile = userDefaults.string(forKey: Keys.transcriptProcessingProfile)
            .flatMap(TranscriptProcessingProfile.init(rawValue:))
        transcriptProcessingProfile = storedTranscriptProcessingProfile ?? .cleanTranscript

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

        resetSetupStateForApplicationSupportStorageIfNeeded()
    }

    private func resetSetupStateForApplicationSupportStorageIfNeeded() {
        guard !userDefaults.bool(forKey: Keys.didResetForApplicationSupportModelStorage) else { return }
        modelDownloadsApproved = false
        hasSeenIntroOnboarding = false
        userDefaults.set(true, forKey: Keys.didResetForApplicationSupportModelStorage)
    }
}

private enum Keys {
    static let modelDownloadsApproved = "modelDownloadsApproved"
    static let whisperTinyModelApproved = "whisperTinyModelApproved"
    static let transcriptionModel = "transcriptionModel"
    static let launchAtLogin = "launchAtLogin"
    static let transcriptProcessingProfile = "transcriptProcessingProfile"
    static let activationSound = "activationSound"
    static let deactivationSound = "deactivationSound"
    static let pushToTalkHotkey = "pushToTalkHotkey"
    static let basicDiagnosticsEnabled = "basicDiagnosticsEnabled"
    static let hasSeenIntroOnboarding = "hasSeenIntroOnboarding"
    static let didResetForApplicationSupportModelStorage = "didResetForApplicationSupportModelStorage"
}
