import AppKit

@MainActor
final class OutputManager {
    func copyToClipboard(_ text: String) {
        let normalizedText = TranscriptOutputFormatter.normalizedText(text)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(normalizedText, forType: .string)
    }
}
