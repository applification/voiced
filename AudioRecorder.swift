import AVFoundation

final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var tempURL: URL?

    func start() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")
        file = try AVAudioFile(forWriting: tmp, settings: format.settings)
        tempURL = tmp

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let self, let file = self.file else { return }
            do { try file.write(from: buffer) } catch { Log.audio.error("Failed to write buffer: \(String(describing: error), privacy: .public)") }
        }
        try engine.start()
    }

    func stop() -> URL? {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        let url = tempURL
        file = nil
        tempURL = nil
        return url
    }
}
