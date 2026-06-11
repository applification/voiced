import Foundation

enum TranscriptOutputFormatter {
    static func normalizedText(_ text: String, profile: TranscriptProcessingProfile? = nil) -> String {
        switch profile {
        case .cleanTranscript:
            LiveTranscriptState.sanitizedText(text)
        case .executiveSummary, .todoList:
            normalizedMarkdownListText(text)
        case nil:
            normalizedMarkdownListText(text)
        }
    }

    static func htmlRepresentation(for text: String) -> String? {
        let normalizedText = normalizedMarkdownListText(text)
        guard let items = markdownListItems(in: normalizedText) else { return nil }

        let listItems = items
            .map { item in
                let prefix = item.isChecklist ? "&#x2610; " : ""
                return "<li>\(prefix)\(escapedHTML(item.text))</li>"
            }
            .joined()

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        body { font: -apple-system-body; margin: 0; }
        ul { margin: 0; padding-left: 1.4em; }
        li { margin: 0.2em 0; }
        </style>
        </head>
        <body><ul>\(listItems)</ul></body>
        </html>
        """
    }

    static func normalizedMarkdownListText(_ text: String) -> String {
        var normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        normalizedText = insertLineBreaks(in: normalizedText, before: "- [ ] ")
        normalizedText = insertLineBreaks(in: normalizedText, before: "- [x] ")
        normalizedText = insertLineBreaks(in: normalizedText, before: "- [X] ")

        if normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("- ") {
            normalizedText = insertLineBreaks(in: normalizedText, before: "- ")
        }

        return normalizedText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func insertLineBreaks(in text: String, before marker: String) -> String {
        var result = ""
        var searchStart = text.startIndex
        var hasSeenMarker = false

        while let range = text.range(of: marker, range: searchStart..<text.endIndex) {
            result.append(contentsOf: text[searchStart..<range.lowerBound])
            if hasSeenMarker, result.last != "\n" {
                result.append("\n")
            }
            result.append(contentsOf: marker)
            searchStart = range.upperBound
            hasSeenMarker = true
        }

        result.append(contentsOf: text[searchStart..<text.endIndex])
        return result
    }

    private static func markdownListItems(in text: String) -> [(isChecklist: Bool, text: String)]? {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        var items: [(isChecklist: Bool, text: String)] = []
        for line in lines {
            if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
                let taskStart = line.index(line.startIndex, offsetBy: 6)
                items.append((isChecklist: true, text: String(line[taskStart...])))
            } else if line.hasPrefix("- ") {
                let itemStart = line.index(line.startIndex, offsetBy: 2)
                items.append((isChecklist: false, text: String(line[itemStart...])))
            } else {
                return nil
            }
        }

        return items.isEmpty ? nil : items
    }

    private static func escapedHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
