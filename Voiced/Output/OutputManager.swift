import AppKit
import os

enum OutputBehavior {
    case review
    case copyOnly
}

@MainActor
final class OutputManager {
    private static let logger = Logger(subsystem: "net.applification.voiced", category: "output")
    private static var restoreTask: DispatchWorkItem?

    private struct SavedPasteboardItem {
        let dataByType: [(NSPasteboard.PasteboardType, Data)]
    }

    func performOutput(_ text: String, behavior: OutputBehavior) {
        switch behavior {
        case .review:
            copyToClipboard(text)
        case .copyOnly:
            copyToClipboard(text)
        }
    }

    func copyToClipboard(_ text: String) {
        Self.restoreTask?.cancel()
        Self.restoreTask = nil
        let changed = Self.writeStringToPasteboard(text)
        Self.logger.info("Copied text to clipboard; success=\(changed, privacy: .public) characters=\(text.count, privacy: .public)")
    }

    func copyToClipboard(_ text: String, restoringAfter seconds: TimeInterval) {
        let pb = NSPasteboard.general
        Self.restoreTask?.cancel()
        Self.restoreTask = nil
        let previousItems = Self.snapshotPasteboard(pb)
        let changed = Self.writeStringToPasteboard(text)
        let transcriptGeneration = pb.changeCount
        Self.logger.info("Copied text to clipboard temporarily; success=\(changed, privacy: .public) seconds=\(seconds, privacy: .public) characters=\(text.count, privacy: .public)")

        guard seconds > 0 else { return }
        let restoreTask = DispatchWorkItem {
            let pb2 = NSPasteboard.general
            guard pb2.changeCount == transcriptGeneration else { return }
            Self.restorePasteboard(pb2, from: previousItems)
            Self.logger.info("Restored previous pasteboard after temporary copy")
        }
        Self.restoreTask = restoreTask
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: restoreTask)
    }

    @discardableResult
    private static func writeStringToPasteboard(_ text: String) -> Bool {
        let pb = NSPasteboard.general
        pb.clearContents()
        return pb.setString(text, forType: .string)
    }

    private static func snapshotPasteboard(_ pasteboard: NSPasteboard) -> [SavedPasteboardItem] {
        pasteboard.pasteboardItems?.compactMap { item in
            let dataByType = item.types.compactMap { type -> (NSPasteboard.PasteboardType, Data)? in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }

            guard !dataByType.isEmpty else { return nil }
            return SavedPasteboardItem(dataByType: dataByType)
        } ?? []
    }

    private static func restorePasteboard(_ pasteboard: NSPasteboard, from savedItems: [SavedPasteboardItem]) {
        pasteboard.clearContents()
        guard !savedItems.isEmpty else { return }

        let restoredItems = savedItems.map { savedItem in
            let item = NSPasteboardItem()
            for (type, data) in savedItem.dataByType {
                item.setData(data, forType: type)
            }
            return item
        }

        if !pasteboard.writeObjects(restoredItems) {
            pasteboard.clearContents()
            if let firstString = restoredItems.compactMap({ $0.string(forType: .string) }).first {
                pasteboard.setString(firstString, forType: .string)
            }
        }
    }

}
