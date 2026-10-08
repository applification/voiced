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

enum AccessibilitySelection {
    case text(String, url: URL?)
    case empty
    case unavailable
}

@MainActor
protocol SelectionAccessibilityReading: AnyObject {
    var isAuthorized: Bool { get }
    func selection(from context: DestinationApplicationContext) -> AccessibilitySelection
}

@MainActor
final class SelectedTextCaptureService {
    private let pasteboard: any PasteboardAccessing
    private let accessibility: any SelectionAccessibilityReading
    private let postCopy: @MainActor () -> Bool

    init(
        pasteboard: any PasteboardAccessing = GeneralPasteboard(),
        accessibility: any SelectionAccessibilityReading = SystemSelectionAccessibilityReader(),
        postCopy: @escaping @MainActor () -> Bool = OutputManager.postCommandC
    ) {
        self.pasteboard = pasteboard
        self.accessibility = accessibility
        self.postCopy = postCopy
    }

    func capture(from context: DestinationApplicationContext) async throws -> SelectedTextCaptureResult {
        guard accessibility.isAuthorized else { throw SelectedTextCaptureError.accessibilityRequired }

        switch accessibility.selection(from: context) {
        case .text(let text, let url):
            return SelectedTextCaptureResult(
                text: text,
                sourceApplication: CaptureSourceApplication(
                    name: context.name,
                    bundleIdentifier: context.bundleIdentifier,
                    url: url
                )
            )
        case .empty:
            // Copy with no selection can make the destination app beep. Only
            // use the clipboard fallback when Accessibility cannot read it.
            throw SelectedTextCaptureError.noSelection
        case .unavailable:
            break
        }

        guard let application = NSRunningApplication(processIdentifier: context.processIdentifier),
              !application.isTerminated else {
            throw SelectedTextCaptureError.noSelection
        }
        _ = application.activate(options: [.activateAllWindows])
        try? await Task.sleep(for: .milliseconds(100))

        let snapshot = pasteboard.snapshot()
        let initialChangeCount = pasteboard.changeCount
        guard postCopy() else {
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
}

@MainActor
final class SystemSelectionAccessibilityReader: SelectionAccessibilityReading {
    var isAuthorized: Bool { AXIsProcessTrusted() }

    func selection(from context: DestinationApplicationContext) -> AccessibilitySelection {
        let applicationElement = AXUIElementCreateApplication(context.processIdentifier)
        guard let focusedElement = axElement(from: value(
            of: kAXFocusedUIElementAttribute as CFString,
            from: applicationElement
        )) else { return .unavailable }

        if let text = value(of: kAXSelectedTextAttribute as CFString, from: focusedElement) as? String {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .empty }
            let url = safeURL(from: value(of: kAXURLAttribute as CFString, from: focusedElement))
                ?? focusedWindowURL(from: applicationElement)
            return .text(text, url: url)
        }

        if let selectedRange = value(of: kAXSelectedTextRangeAttribute as CFString, from: focusedElement),
           CFGetTypeID(selectedRange) == AXValueGetTypeID() {
            let axRange = unsafeDowncast(selectedRange as AnyObject, to: AXValue.self)
            var range = CFRange()
            if AXValueGetValue(axRange, .cfRange, &range), range.length == 0 {
                return .empty
            }
        }
        return .unavailable
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
