enum OutputMode: String, CaseIterable, Identifiable {
    case review = "clipboardPaste"
    case copyOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .review:
            "Review"
        case .copyOnly:
            "Copy"
        }
    }
}
