import AppKit
import CoreGraphics
import os

enum OutputResult: Equatable {
    case copied
    case inserted
    case accessibilityRequired
    case failed
}

@MainActor
final class OutputManager {
    private static let logger = Logger(subsystem: "net.applification.voiced", category: "output")

    private let pasteboard: any PasteboardAccessing

    init(pasteboard: any PasteboardAccessing = GeneralPasteboard()) {
        self.pasteboard = pasteboard
    }

    @discardableResult
    func copyToClipboard(_ text: String) -> OutputResult {
        let normalizedText = TranscriptOutputFormatter.normalizedText(text)
        guard !normalizedText.isEmpty else { return .failed }
        return pasteboard.writeString(normalizedText) ? .copied : .failed
    }

    func insert(
        _ text: String,
        into targetApplication: NSRunningApplication?,
        guardBeforePaste: (@MainActor () -> Bool)? = nil
    ) async -> OutputResult {
        guard !Task.isCancelled, guardBeforePaste?() != false else { return .failed }
        guard AXIsProcessTrusted() else { return .accessibilityRequired }

        let normalizedText = TranscriptOutputFormatter.normalizedText(text)
        guard !normalizedText.isEmpty,
              let transaction = ClipboardTransaction.replacingText(normalizedText, on: pasteboard) else {
            return .failed
        }

        if let targetApplication, !targetApplication.isTerminated {
            _ = targetApplication.activate(options: [.activateAllWindows])
            try? await Task.sleep(for: .milliseconds(180))
        }

        guard !Task.isCancelled, guardBeforePaste?() != false,
              targetApplication == nil || NSWorkspace.shared.frontmostApplication?.processIdentifier == targetApplication?.processIdentifier,
              Self.postCommandV() else {
            _ = transaction.restoreIfUnchanged(on: pasteboard)
            return .failed
        }

        // Once the paste is posted, cancellation must not restore the old clipboard
        // before the destination has had time to consume the new contents.
        await Task.detached { try? await Task.sleep(for: .milliseconds(420)) }.value
        let restored = transaction.restoreIfUnchanged(on: pasteboard)
        Self.logger.info("Automatic insertion completed; clipboardRestored=\(restored, privacy: .public)")
        return .inserted
    }

    @discardableResult
    static func postCommandC() -> Bool {
        postCommandKey(keyCode: 8)
    }

    @discardableResult
    private static func postCommandV() -> Bool {
        postCommandKey(keyCode: 9)
    }

    @discardableResult
    private static func postCommandKey(keyCode: CGKeyCode) -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return false
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
        return true
    }
}
