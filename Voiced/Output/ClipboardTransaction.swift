import AppKit
import Foundation

struct ClipboardItemSnapshot: Equatable, Sendable {
    var values: [String: Data]
}

struct ClipboardSnapshot: Equatable, Sendable {
    var items: [ClipboardItemSnapshot]
}

@MainActor
protocol PasteboardAccessing: AnyObject {
    var changeCount: Int { get }
    func snapshot() -> ClipboardSnapshot
    @discardableResult func writeString(_ text: String) -> Bool
    func readString() -> String?
    @discardableResult func restore(_ snapshot: ClipboardSnapshot) -> Bool
}

@MainActor
struct ClipboardTransaction {
    let snapshot: ClipboardSnapshot
    let expectedChangeCount: Int

    static func replacingText(
        _ text: String,
        on pasteboard: any PasteboardAccessing
    ) -> ClipboardTransaction? {
        let snapshot = pasteboard.snapshot()
        guard pasteboard.writeString(text) else { return nil }
        return ClipboardTransaction(snapshot: snapshot, expectedChangeCount: pasteboard.changeCount)
    }

    @discardableResult
    func restoreIfUnchanged(on pasteboard: any PasteboardAccessing) -> Bool {
        guard pasteboard.changeCount == expectedChangeCount else { return false }
        return pasteboard.restore(snapshot)
    }
}

@MainActor
final class GeneralPasteboard: PasteboardAccessing {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int { pasteboard.changeCount }

    func snapshot() -> ClipboardSnapshot {
        let items: [ClipboardItemSnapshot] = pasteboard.pasteboardItems?.map { item in
            var values: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    values[type.rawValue] = data
                }
            }
            return ClipboardItemSnapshot(values: values)
        } ?? []
        return ClipboardSnapshot(items: items)
    }

    @discardableResult
    func writeString(_ text: String) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    func readString() -> String? {
        pasteboard.string(forType: .string)
    }

    @discardableResult
    func restore(_ snapshot: ClipboardSnapshot) -> Bool {
        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else { return true }

        let items = snapshot.items.map { saved in
            let item = NSPasteboardItem()
            for (rawType, data) in saved.values {
                item.setData(data, forType: NSPasteboard.PasteboardType(rawType))
            }
            return item
        }
        return pasteboard.writeObjects(items)
    }
}
