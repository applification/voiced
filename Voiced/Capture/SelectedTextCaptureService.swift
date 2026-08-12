import AppKit
@preconcurrency import ApplicationServices
import Foundation

enum SelectedTextCaptureError: Error, Equatable {
    case accessibilityRequired
    case noSelection
    case copyFallbackFailed
}

struct SelectedTextCaptureResult: Equatable {
    var text: String
    var sourceApplication: CaptureSourceApplication
}

@MainActor
final class SelectedTextCaptureService {
    private let pasteboard: any PasteboardAccessing

    init(pasteboard: any PasteboardAccessing = GeneralPasteboard()) {
        self.pasteboard = pasteboard
    }

    func capture(from context: DestinationApplicationContext) async throws -> SelectedTextCaptureResult {
        guard AXIsProcessTrusted() else { throw SelectedTextCaptureError.accessibilityRequired }

        let applicationElement = AXUIElementCreateApplication(context.processIdentifier)
        if let direct = selectedText(from: applicationElement) {
            return SelectedTextCaptureResult(
                text: direct.text,
                sourceApplication: CaptureSourceApplication(
                    name: context.name,
                    bundleIdentifier: context.bundleIdentifier,
                    url: direct.url
                )
            )
        }

        guard let application = NSRunningApplication(processIdentifier: context.processIdentifier),
              !application.isTerminated else {
            throw SelectedTextCaptureError.noSelection
        }
        _ = application.activate(options: [.activateAllWindows])
        try? await Task.sleep(for: .milliseconds(100))

        let snapshot = pasteboard.snapshot()
        let initialChangeCount = pasteboard.changeCount
        guard OutputManager.postCommandC() else {
            throw SelectedTextCaptureError.copyFallbackFailed
        }

        var copiedText: String?
        for _ in 0..<8 {
            try? await Task.sleep(for: .milliseconds(50))
            guard pasteboard.changeCount != initialChangeCount else { continue }
            copiedText = pasteboard.readString()
            break
        }

        let transaction = ClipboardTransaction(
            snapshot: snapshot,
            expectedChangeCount: pasteboard.changeCount
        )
        _ = transaction.restoreIfUnchanged(on: pasteboard)

        guard let copiedText,
              !copiedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SelectedTextCaptureError.noSelection
        }
        return SelectedTextCaptureResult(
            text: copiedText,
            sourceApplication: context.captureSource
        )
    }

    private func selectedText(from applicationElement: AXUIElement) -> (text: String, url: URL?)? {
        guard let focusedElement = axElement(from: value(
            of: kAXFocusedUIElementAttribute as CFString,
            from: applicationElement
        )),
        let text = value(of: kAXSelectedTextAttribute as CFString, from: focusedElement) as? String,
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let url = safeURL(from: value(of: kAXURLAttribute as CFString, from: focusedElement))
            ?? focusedWindowURL(from: applicationElement)
        return (text, url)
    }

    private func focusedWindowURL(from applicationElement: AXUIElement) -> URL? {
        guard let window = axElement(from: value(
            of: kAXFocusedWindowAttribute as CFString,
            from: applicationElement
        )) else { return nil }
        return safeURL(from: value(of: kAXDocumentAttribute as CFString, from: window))
    }

    private func value(of attribute: CFString, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value
    }

    private func axElement(from value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value as AnyObject, to: AXUIElement.self)
    }

    private func safeURL(from value: CFTypeRef?) -> URL? {
        if let url = value as? URL {
            return allowed(url) ? url : nil
        }
        if let string = value as? String, let url = URL(string: string) {
            return allowed(url) ? url : nil
        }
        return nil
    }

    private func allowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "https" || scheme == "http" || scheme == "file"
    }
}
