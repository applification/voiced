@preconcurrency import AVFoundation
import FluidAudio
import Foundation

@MainActor
final class ParakeetTranscriptionService: AppTranscribing {
    private let settings: SettingsStore
    private var models: AsrModels?
    private var vocabularyModels: CtcModels?
    private var samples: [Float] = []
    private var sessionVocabulary: [String] = []
    private var audioConversionFailed = false
    private var engine: AVAudioEngine?
    private var input: AsyncStream<OwnedAudioBuffer>.Continuation?
    private var audioTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    var onModelProgress: ((ModelLoadProgress) -> Void)?

    init(settings: SettingsStore) { self.settings = settings }
    var isSelectedModelLoaded: Bool { models != nil && vocabularyModels != nil }

    func loadModelIfNeeded() async throws {
        guard !isSelectedModelLoaded else { return }
        guard settings.modelDownloadsApproved else {
            throw TranscriptionError.modelDownloadNotApproved("Parakeet v2 English")
        }
        // Only this explicit preparation path permits network access. Decoding uses preloaded models.
        try SpeechRuntimePrivacy.silenceDependencyConsole()
        ModelHub.offlineMode = false
        defer {
            ModelHub.offlineMode = true
            ModelStatusCache.refresh(.parakeetV2)
        }
        report("Preparing Parakeet", 0)
        let loaded = try await AsrModels.downloadAndLoad(version: .v2) { [weak self] progress in
            Task { @MainActor in self?.report("Downloading Parakeet", progress.fractionCompleted * 0.85) }
        }
        report("Preparing vocabulary model", 0.9)
        let ctc = try await CtcModels.downloadAndLoad()
        // Fail preparation clearly if the required tokenizer is missing, rather than silently
        // accepting a vocabulary which cannot influence recognition.
        _ = try await CtcTokenizer.load(from: CtcModels.defaultCacheDirectory())
        models = loaded
        vocabularyModels = ctc
        LoadedModelState.markLoaded(.parakeetV2)
        report("Loaded", 1)
    }

    private func report(_ phase: String, _ fraction: Double) {
        onModelProgress?(ModelLoadProgress(model: .parakeetV2, phase: phase, fractionCompleted: fraction))
        if phase == "Loaded" {
            NotificationCenter.default.post(name: .voicedModelStatusChanged, object: TranscriptionModel.parakeetV2)
        }
    }

    func startLiveTranscription(
        onUpdate: @escaping @MainActor (LiveTranscriptState) -> Void,
        onAudioLevel: @escaping @MainActor (Double) -> Void
    ) async throws {
        guard let models else { throw TranscriptionError.modelNotLoaded }
        sessionVocabulary = PersonalVocabulary.normalized(settings.vocabulary)
        samples = []
        audioConversionFailed = false
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        // Re-decode the growing utterance. Short SDK sliding windows split words in
        // our M1 audio check. Only one preview inference runs at a time; no backlog.
        // The whole draft stays provisional until the final vocabulary-aware pass.
        previewTask = Task { [weak self] in
            var lastSampleCount = 0
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(900))
                    guard let self else { return }
                    let audio = self.samples
                    guard audio.count - lastSampleCount >= 8_000 else { continue }
                    lastSampleCount = audio.count
                    var state = TdtDecoderState.make(decoderLayers: models.version.decoderLayers)
                    let result = try await manager.transcribe(audio, decoderState: &state)
                    try Task.checkCancellation()
                    onUpdate(LiveTranscriptState(committedText: "",
                        provisionalText: LiveTranscriptState.sanitizedText(result.text), isRecording: true))
                } catch is CancellationError { return }
                catch { /* Keep the last preview; final recognition surfaces a failure. */ }
            }
        }
        let converter = AudioConverter()
        let (buffers, continuation) = AsyncStream<OwnedAudioBuffer>.makeStream()
        input = continuation
        // A single consumer preserves capture order and is drained before the final flush.
        audioTask = Task {
            for await owned in buffers {
                do { self.samples.append(contentsOf: try converter.resampleBuffer(owned.buffer)) }
                catch { self.audioConversionFailed = true }
                onAudioLevel(owned.level)
            }
        }
        let engine = AVAudioEngine()
        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            await cancelLiveTranscription()
            throw TranscriptionError.noResult
        }
        node.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            if let owned = OwnedAudioBuffer(copying: buffer) { continuation.yield(owned) }
        }
        self.engine = engine
        do {
            try engine.start()
        } catch {
            await cancelLiveTranscription()
            throw error
        }
        onUpdate(LiveTranscriptState(committedText: "", provisionalText: "", isRecording: true))
    }

    func stopLiveTranscription() async throws -> String {
        guard engine != nil || audioTask != nil else { return "" }
        await stopAudioAndPreview()
        defer { samples = [] }
        guard !audioConversionFailed else { throw TranscriptionError.noResult }
        return try await finalTranscription(samples)
    }

    private func stopAudioAndPreview() async {
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        engine = nil
        input?.finish()
        input = nil
        previewTask?.cancel()
        await audioTask?.value
        await previewTask?.value
        audioTask = nil
        previewTask = nil
    }

    private func finalTranscription(_ audio: [Float]) async throws -> String {
        guard let models, let vocabularyModels, !audio.isEmpty else { return "" }
        try Task.checkCancellation()
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        var decoderState = TdtDecoderState.make(decoderLayers: models.version.decoderLayers)
        let result = try await manager.transcribe(audio, decoderState: &decoderState)
        var text = result.text
        if !sessionVocabulary.isEmpty, let timings = result.tokenTimings {
            let boosting = try await VocabularyBoostingSession(
                vocabulary: CustomVocabularyContext(terms: sessionVocabulary.map { CustomVocabularyTerm(text: $0) }, minSimilarity: 0.8),
                ctcModels: vocabularyModels,
                config: VocabularyRescorer.Config(shortTermCbwTaperPivot: 5, spotterRescueEnabled: false)
            )
            text = await boosting.rescore(text: text, tokenTimings: timings, audioSamples: audio)?.text ?? text
        }
        return LiveTranscriptState.sanitizedText(text)
    }

    func cancelLiveTranscription() async {
        await stopAudioAndPreview()
        samples = []
    }

    func transcribeFile(at url: URL) async throws -> String {
        try await loadModelIfNeeded()
        sessionVocabulary = PersonalVocabulary.normalized(settings.vocabulary)
        let audio = try AudioConverter().resampleAudioFile(url)
        return try await finalTranscription(audio)
    }
}

/// Owns a copy because AVAudioEngine reuses its tap buffers. The copy is never mutated
/// after construction and crosses the callback boundary through AsyncStream.
private struct OwnedAudioBuffer: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    let level: Double

    init?(copying source: AVAudioPCMBuffer) {
        guard let copy = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: source.frameLength) else { return nil }
        copy.frameLength = source.frameLength
        let sourceBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: source.audioBufferList))
        let targetBuffers = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for (source, target) in zip(sourceBuffers, targetBuffers) {
            guard let from = source.mData, let to = target.mData else { return nil }
            memcpy(to, from, Int(source.mDataByteSize))
        }
        buffer = copy
        if let channel = copy.floatChannelData?[0], copy.frameLength > 0 {
            let samples = UnsafeBufferPointer(start: channel, count: Int(copy.frameLength))
            let rms = sqrt(samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(samples.count))
            level = min(1, rms * 8)
        } else { level = 0 }
    }
}
