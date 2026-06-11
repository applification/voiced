import Foundation

enum TranscriptProcessingProfile: String, CaseIterable, Identifiable {
    case cleanTranscript
    case executiveSummary
    case todoList

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cleanTranscript:
            "Clean transcript"
        case .executiveSummary:
            "Executive summary"
        case .todoList:
            "To-do list"
        }
    }

    var detail: String {
        switch self {
        case .cleanTranscript:
            "Remove filler words and false starts while preserving meaning."
        case .executiveSummary:
            "Return 3-5 concise bullets focused on outcomes, decisions, and risks."
        case .todoList:
            "Turn spoken tasks into a concise markdown checklist."
        }
    }

    var menuTitle: String { label }
}
