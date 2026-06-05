import AVFoundation

final class AudioRecorder {
    private var recorder: AVAudioRecorder?
    private var tempURL: URL?

    func start() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: tmp, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw AudioRecorderError.failedToStart
        }

        self.recorder = recorder
        self.tempURL = tmp
    }

    func stop() -> URL? {
        recorder?.stop()
        let url = tempURL
        recorder = nil
        tempURL = nil
        return url
    }

    func currentLevel() -> Double {
        guard let recorder, recorder.isRecording else { return 0 }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        guard power.isFinite else { return 0 }
        let normalized = max(0, min(1, (Double(power) + 55) / 55))
        return pow(normalized, 1.6)
    }
}

enum AudioRecorderError: LocalizedError {
    case failedToStart

    var errorDescription: String? {
        "Audio recording could not be started."
    }
}
