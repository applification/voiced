import WhisperKit

enum TranscriptionVocabulary {
    static let terms = [
        "Voiced",
        "WhisperKit",
        "SwiftUI",
        "Xcode",
        "Contexture",
        "Applification",
    ]

    static var promptText: String {
        terms.joined(separator: ", ")
    }

    static func decodingOptions(
        tokenizer: any WhisperTokenizer,
        wordTimestamps: Bool
    ) -> DecodingOptions {
        let promptTokens = tokenizer
            .encode(text: " \(promptText)")
            .filter { $0 < tokenizer.specialTokens.specialTokenBegin }

        return DecodingOptions(
            language: "en",
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            wordTimestamps: wordTimestamps,
            promptTokens: promptTokens
        )
    }
}
