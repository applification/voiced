import Foundation

struct LiveTranscriptState: Equatable {
    var committedText: String
    var provisionalText: String
    var isRecording: Bool

    static let idle = LiveTranscriptState(
        committedText: "",
        provisionalText: "",
        isRecording: false
    )

    var combinedText: String {
        [committedText, provisionalText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "Waiting for speech..." }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
