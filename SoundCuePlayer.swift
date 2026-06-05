import AppKit
import os

@MainActor
final class SoundCuePlayer {
    private static let logger = Logger(subsystem: "com.voiced.app", category: "sound")

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func playActivation() {
        play(settings.activationSound, volume: 0.45, label: "activation")
    }

    func playDeactivation() {
        play(settings.deactivationSound, volume: 0.38, label: "deactivation")
    }

    private func play(_ cue: SoundCue, volume: Float, label: String) {
        guard let soundName = cue.soundName else { return }
        let sound = NSSound(named: soundName)
        guard let sound else {
            Self.logger.warning("Sound cue missing; label=\(label, privacy: .public)")
            return
        }

        sound.volume = volume
        if sound.isPlaying {
            sound.stop()
        }
        sound.currentTime = 0
        sound.play()
    }
}
