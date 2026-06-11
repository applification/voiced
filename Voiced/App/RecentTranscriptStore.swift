import Foundation
import os
#if canImport(FoundationModels)
import FoundationModels
#endif

struct RecentTranscript: Identifiable, Equatable {
    let id: UUID
    var title: String
    var text: String
    let createdAt: Date
    let expiresAt: Date
}

@MainActor
final class RecentTranscriptStore {
    private(set) var items: [RecentTranscript] = []

    private let maxItems: Int
    private let lifetime: TimeInterval
    private let titleGenerator: RecentTranscriptTitleGenerating
    private let clock: () -> Date

    init(
        maxItems: Int = 5,
        lifetime: TimeInterval = 60 * 60,
        titleGenerator: RecentTranscriptTitleGenerating = RecentTranscriptTitleGenerator(),
        clock: @escaping () -> Date = Date.init
    ) {
        self.maxItems = max(1, maxItems)
        self.lifetime = lifetime
        self.titleGenerator = titleGenerator
        self.clock = clock
    }

    @discardableResult
    func add(text: String) -> RecentTranscript? {
        let normalizedText = LiveTranscriptState.sanitizedText(text)
        guard !normalizedText.isEmpty else { return nil }

        removeExpired()

        let now = clock()
        let transcript = RecentTranscript(
            id: UUID(),
            title: Self.fallbackTitle(for: normalizedText, createdAt: now),
            text: normalizedText,
            createdAt: now,
            expiresAt: now.addingTimeInterval(lifetime)
        )
        items.insert(transcript, at: 0)
        trimToLimit()
        postChangeNotification()

        regenerateTitle(for: transcript.id, text: normalizedText)

        return transcript
    }

    func updateMostRecent(text: String) {
        let normalizedText = LiveTranscriptState.sanitizedText(text)
        guard !normalizedText.isEmpty else { return }

        removeExpired()
        guard let transcript = items.first else {
            add(text: normalizedText)
            return
        }
        guard transcript.text != normalizedText else { return }

        items[0].text = normalizedText
        items[0].title = Self.fallbackTitle(for: normalizedText, createdAt: transcript.createdAt)
        postChangeNotification()
        regenerateTitle(for: transcript.id, text: normalizedText)
    }

    func transcript(id: UUID) -> RecentTranscript? {
        removeExpired()
        return items.first { $0.id == id }
    }

    func clear() {
        guard !items.isEmpty else { return }
        items.removeAll()
        postChangeNotification()
    }

    func removeExpired() {
        let now = clock()
        let originalCount = items.count
        items.removeAll { $0.expiresAt <= now }
        if items.count != originalCount {
            postChangeNotification()
        }
    }

    private func regenerateTitle(for id: UUID, text: String) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let generatedTitle = await self.titleGenerator.title(for: text) else { return }
            self.updateTitle(generatedTitle, for: id, expectedText: text)
        }
    }

    private func updateTitle(_ title: String, for id: UUID, expectedText: String) {
        let cleanedTitle = Self.cleanedTitle(title)
        guard !cleanedTitle.isEmpty else { return }
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard items[index].text == expectedText else { return }
        items[index].title = cleanedTitle
        postChangeNotification()
    }

    private func trimToLimit() {
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
    }

    private func postChangeNotification() {
        NotificationCenter.default.post(name: .voicedRecentTranscriptsChanged, object: self)
    }

    private static func fallbackTitle(for text: String, createdAt: Date) -> String {
        let words = text
            .split { $0.isWhitespace || $0.isNewline }
            .prefix(5)
            .map(String.init)
            .joined(separator: " ")
            .trimmingCharacters(in: .punctuationCharacters)

        if words.count >= 8 {
            return words.count > 42 ? String(words.prefix(39)) + "..." : words
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "Transcript \(formatter.string(from: createdAt))"
    }

    private static func cleanedTitle(_ title: String) -> String {
        var cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") && cleaned.count > 1 {
            cleaned.removeFirst()
            cleaned.removeLast()
        }
        cleaned = cleaned.replacingOccurrences(of: "\n", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        return cleaned.count > 48 ? String(cleaned.prefix(45)) + "..." : cleaned
    }
}

@MainActor
protocol RecentTranscriptTitleGenerating: AnyObject {
    func title(for transcript: String) async -> String?
}

@MainActor
final class RecentTranscriptTitleGenerator: RecentTranscriptTitleGenerating {
    private let logger = Logger(subsystem: "net.applification.voiced", category: "recent-transcripts")

    func title(for transcript: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return await titleWithFoundationModels(for: transcript)
        }
        #endif

        return nil
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func titleWithFoundationModels(for transcript: String) async -> String? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }
        guard model.supportsLocale() else { return nil }

        do {
            let session = LanguageModelSession(instructions: """
            Create concise titles for recent speech transcripts.
            - Use 3 to 6 words.
            - Do not invent facts not present in the transcript.
            - Return only the title.
            """)
            let response = try await session.respond(
                to: "Transcript:\n\(transcript)",
                options: GenerationOptions(
                    sampling: .greedy,
                    temperature: 0.1,
                    maximumResponseTokens: 24
                )
            )
            return response.content
        } catch is CancellationError {
            return nil
        } catch {
            logger.error("FoundationModels title generation failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
    #endif
}
