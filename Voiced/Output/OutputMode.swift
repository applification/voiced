enum OutputMode: String, CaseIterable, Identifiable {
    case clipboardPaste
    case copyOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .clipboardPaste:
            "Paste"
        case .copyOnly:
            "Copy"
        }
    }
}
