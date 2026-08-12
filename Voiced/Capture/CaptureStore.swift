import Foundation
import Observation

struct CaptureStoreDocument: Codable, Equatable, Sendable {
    var version = 1
    var items: [CaptureItem]
}

enum CaptureStoreIssue: Equatable {
    case recoveredCorruptFile(URL)
    case readFailed
    case writeFailed

    var message: String {
        switch self {
        case .recoveredCorruptFile:
            "The capture file could not be read. Voiced preserved a recovery copy and started with an empty shelf."
        case .readFailed:
            "Voiced could not read the local capture file."
        case .writeFailed:
            "Voiced could not save the latest shelf change. Check the Application Support folder permissions."
        }
    }
}

@MainActor
@Observable
final class CaptureStore {
    private(set) var items: [CaptureItem] = []
    private(set) var issue: CaptureStoreIssue?

    let fileURL: URL

    private let fileManager: FileManager
    private let clock: () -> Date
    private let idProvider: () -> UUID
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileURL: URL = CaptureStore.defaultFileURL(),
        fileManager: FileManager = .default,
        clock: @escaping () -> Date = Date.init,
        idProvider: @escaping () -> UUID = UUID.init
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.clock = clock
        self.idProvider = idProvider

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        load()
    }

    static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return applicationSupport
            .appendingPathComponent("Voiced", isDirectory: true)
            .appendingPathComponent("Captures.json", isDirectory: false)
    }

    @discardableResult
    func add(
        text: String,
        source: CaptureSource,
        status: CaptureStatus = .inbox,
        sourceApplication: CaptureSourceApplication? = nil
    ) -> CaptureItem? {
        let normalized = Self.normalized(text)
        guard !normalized.isEmpty else { return nil }

        let now = clock()
        let item = CaptureItem(
            id: idProvider(),
            text: normalized,
            source: source,
            status: status,
            createdAt: now,
            updatedAt: now,
            sourceApplication: sourceApplication
        )
        items.insert(item, at: 0)
        persist()
        return item
    }

    func item(id: UUID) -> CaptureItem? {
        items.first { $0.id == id }
    }

    func updateText(id: UUID, text: String) {
        let normalized = Self.normalized(text)
        guard !normalized.isEmpty,
              let index = items.firstIndex(where: { $0.id == id }),
              items[index].text != normalized else { return }
        items[index].text = normalized
        items[index].updatedAt = clock()
        persist()
    }

    func move(id: UUID, to status: CaptureStatus) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              items[index].status != status else { return }
        items[index].status = status
        items[index].updatedAt = clock()
        persist()
    }

    @discardableResult
    func remove(id: UUID) -> CaptureItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = items.remove(at: index)
        persist()
        return removed
    }

    func restore(_ item: CaptureItem) {
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.append(item)
        items.sort { $0.updatedAt > $1.updatedAt }
        persist()
    }

    func clearIssue() {
        issue = nil
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            guard !data.isEmpty else {
                items = []
                return
            }
            let document = try decoder.decode(CaptureStoreDocument.self, from: data)
            items = document.items.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            items = []
            preserveCorruptFile()
        }
    }

    private func preserveCorruptFile() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let recoveryURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("Captures.corrupt-\(formatter.string(from: clock())).json")
        do {
            try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: recoveryURL.path) {
                try fileManager.removeItem(at: recoveryURL)
            }
            try fileManager.copyItem(at: fileURL, to: recoveryURL)
            issue = .recoveredCorruptFile(recoveryURL)
        } catch {
            issue = .readFailed
        }
    }

    private func persist() {
        do {
            try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let document = CaptureStoreDocument(items: items)
            let data = try encoder.encode(document)
            try data.write(to: fileURL, options: .atomic)
            if case .writeFailed = issue {
                issue = nil
            }
            NotificationCenter.default.post(name: .voicedCapturesChanged, object: self)
        } catch {
            issue = .writeFailed
        }
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
