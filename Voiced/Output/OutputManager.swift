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
        into targetApplication: NSRunningApplication?
    ) async -> OutputResult {
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

        guard Self.postCommandV() else {
            _ = transaction.restoreIfUnchanged(on: pasteboard)
            return .failed
        }

        try? await Task.sleep(for: .milliseconds(420))
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
