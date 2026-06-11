import Foundation

struct LiveTranscriptState: Equatable {
    var committedText: String
    var provisionalText: String
    var isRecording: Bool
    var audioLevel: Double

    init(
        committedText: String,
        provisionalText: String,
        isRecording: Bool,
        audioLevel: Double = 0
    ) {
        self.committedText = committedText
        self.provisionalText = provisionalText
        self.isRecording = isRecording
        self.audioLevel = audioLevel
    }

    static let idle = LiveTranscriptState(
        committedText: "",
        provisionalText: "",
        isRecording: false,
        audioLevel: 0
    )

    var combinedText: String {
        [committedText, provisionalText]
            .map(Self.sanitizedText)
            .filter { !$0.isEmpty && !Self.placeholderTexts.contains($0) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func sanitizedText(_ text: String) -> String {
        var result = ""
        var index = text.startIndex
        while index < text.endIndex {
            if text[index...].hasPrefix("<|"),
               let endRange = text[index...].range(of: "|>") {
                index = endRange.upperBound
            } else {
                result.append(text[index])
                index = text.index(after: index)
            }
        }

        return removingNonSpeechMarkers(from: result)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func removingNonSpeechMarkers(from text: String) -> String {
        var result = ""
        var index = text.startIndex
        while index < text.endIndex {
            if text[index] == "[",
               let closeBracket = text[index...].firstIndex(of: "]") {
                let marker = text[text.index(after: index)..<closeBracket]
                    .lowercased()
                    .filter { $0.isLetter || $0.isNumber }
                if nonSpeechMarkers.contains(marker) {
                    index = text.index(after: closeBracket)
                    continue
                }
            }

            result.append(text[index])
            index = text.index(after: index)
        }
        return result
    }

    static func == (lhs: LiveTranscriptState, rhs: LiveTranscriptState) -> Bool {
        lhs.committedText == rhs.committedText
            && lhs.provisionalText == rhs.provisionalText
            && lhs.isRecording == rhs.isRecording
    }

    private static let nonSpeechMarkers: Set<String> = [
        "blankaudio",
        "silence",
        "nospeech"
    ]

    private static let placeholderTexts = [
        "Listening...",
        "Waiting for speech..."
    ]
}
