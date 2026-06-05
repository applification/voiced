import AppKit
import ApplicationServices
import os

enum OutputBehavior {
    case clipboardPaste
    case copyOnly
}

final class OutputManager {
    private static let logger = Logger(subsystem: "com.voiced.app", category: "output")

    private struct SavedPasteboardItem {
        let dataByType: [(NSPasteboard.PasteboardType, Data)]
    }

    func performOutput(_ text: String, behavior: OutputBehavior) {
        switch behavior {
        case .clipboardPaste:
            pastePreservingClipboard(text)
        case .copyOnly:
            copyToClipboard(text)
        }
    }

    func copyToClipboard(_ text: String) {
        DispatchQueue.main.async {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
        }
    }

    func pastePreservingClipboard(_ text: String, targetApplication: NSRunningApplication? = nil) {
        DispatchQueue.main.async {
            let pb = NSPasteboard.general
            let previousItems = Self.snapshotPasteboard(pb)
            pb.clearContents()
            pb.setString(text, forType: .string)
            let transcriptGeneration = pb.changeCount
            let accessibilityTrusted = AXIsProcessTrustedWithOptions(nil)
            let targetName = targetApplication?.localizedName ?? "none"

            Self.logger.info("Prepared transcript paste; target=\(targetName, privacy: .public) accessibilityTrusted=\(accessibilityTrusted, privacy: .public) characters=\(text.count, privacy: .public)")

            guard accessibilityTrusted else {
                Self.logger.warning("Accessibility is not trusted; leaving transcript on clipboard instead of attempting paste")
                return
            }

            if let targetApplication, !targetApplication.isTerminated {
                targetApplication.activate(options: [.activateAllWindows])
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                OutputManager.postCommandV(to: targetApplication)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                let pb2 = NSPasteboard.general
                guard accessibilityTrusted, pb2.changeCount == transcriptGeneration else { return }
                Self.restorePasteboard(pb2, from: previousItems)
                Self.logger.info("Restored previous pasteboard after transcript paste")
            }
        }
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

    private static func postCommandV(to targetApplication: NSRunningApplication?) {
        let vKey: CGKeyCode = 9 // ANSI 'v'
        guard let src = CGEventSource(stateID: .combinedSessionState) else {
            logger.error("Unable to create CGEventSource for paste")
            return
        }
        guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false) else {
            logger.error("Unable to create Cmd+V keyboard events")
            return
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        if let targetApplication, !targetApplication.isTerminated {
            keyDown.postToPid(targetApplication.processIdentifier)
        } else {
            keyDown.post(tap: .cgAnnotatedSessionEventTap)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let targetApplication, !targetApplication.isTerminated {
                keyUp.postToPid(targetApplication.processIdentifier)
                logger.info("Posted synthetic Cmd+V to pid=\(targetApplication.processIdentifier, privacy: .public)")
            } else {
                keyUp.post(tap: .cgAnnotatedSessionEventTap)
                logger.info("Posted synthetic Cmd+V")
            }
        }
    }
}
