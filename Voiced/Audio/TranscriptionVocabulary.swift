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
        wordTimestamps: Bool,
        terms: [String] = Self.terms
    ) -> DecodingOptions {
        let promptTokens = tokenizer
            .encode(text: " \(PersonalVocabulary.normalized(terms).joined(separator: ", "))")
            .filter { $0 < tokenizer.specialTokens.specialTokenBegin }
            .prefix(200)

        return DecodingOptions(
            language: "en",
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            wordTimestamps: wordTimestamps,
            promptTokens: Array(promptTokens)
        )
    }
}
