import Foundation
import WhisperKit

enum LiveTranscriptionFinalizer {
    static func decodingOptions(
        tokenizer: any WhisperTokenizer,
        confirmedThroughSeconds: Float,
        audioSampleCount: Int
    ) -> DecodingOptions {
        let audioDuration = Float(audioSampleCount) / Float(WhisperKit.sampleRate)
        let clipStart = min(max(0, confirmedThroughSeconds), audioDuration)
        var options = TranscriptionVocabulary.decodingOptions(
            tokenizer: tokenizer,
            wordTimestamps: false
        )
        options.clipTimestamps = clipStart > 0 ? [clipStart] : []
        options.windowClipTime = 0
        return options
    }

    static func hasAudioToDecode(
        audioSampleCount: Int,
        confirmedThroughSeconds: Float
    ) -> Bool {
        let confirmedSampleCount = Int(
            max(0, confirmedThroughSeconds) * Float(WhisperKit.sampleRate)
        )
        return audioSampleCount > confirmedSampleCount
    }

    static func mergedText(
        confirmedText: String,
        finalTailText: String,
        fallbackText: String
    ) -> String {
        let tail = LiveTranscriptState.sanitizedText(finalTailText)
        guard !tail.isEmpty else {
            return LiveTranscriptState.sanitizedText(fallbackText)
        }

        return [
            LiveTranscriptState.sanitizedText(confirmedText),
            tail,
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }
}
