import AppKit
import XCTest
@testable import Voiced

final class SelectedTextCaptureServiceTests: XCTestCase {
    @MainActor
    func testEmptySelectionDoesNotCopyOrChangeClipboard() async {
        let pasteboard = SelectionTestPasteboard(text: "Previous clipboard")
        let service = SelectedTextCaptureService(
            pasteboard: pasteboard,
            accessibility: SelectionTestAccessibility(selection: .empty),
            postCopy: { XCTFail("An empty selection must not send Command+C"); return false }
        )

        do {
            _ = try await service.capture(from: context)
            XCTFail("Expected no selection")
        } catch {
            XCTAssertEqual(error as? SelectedTextCaptureError, .noSelection)
        }
        XCTAssertEqual(pasteboard.readString(), "Previous clipboard")
        XCTAssertEqual(pasteboard.changeCount, 0)
    }

    @MainActor
    func testReadableSelectionPreservesSourceAndClipboard() async throws {
        let pasteboard = SelectionTestPasteboard(text: "Previous clipboard")
        let service = SelectedTextCaptureService(
            pasteboard: pasteboard,
            accessibility: SelectionTestAccessibility(selection: .text("Selected text", url: URL(string: "https://example.com"))),
            postCopy: { XCTFail("Readable selections do not need Command+C"); return false }
        )

        let result = try await service.capture(from: context)

        XCTAssertEqual(result.text, "Selected text")
        XCTAssertEqual(result.sourceApplication.name, "Example")
        XCTAssertEqual(result.sourceApplication.url, URL(string: "https://example.com"))
        XCTAssertEqual(pasteboard.readString(), "Previous clipboard")
        XCTAssertEqual(pasteboard.changeCount, 0)
    }

    @MainActor
    func testUnavailableAccessibilitySelectionStillUsesCopyFallbackAndRestoresClipboard() async throws {
        let pasteboard = SelectionTestPasteboard(text: "Previous clipboard")
        let service = SelectedTextCaptureService(
            pasteboard: pasteboard,
            accessibility: SelectionTestAccessibility(selection: .unavailable),
            postCopy: { pasteboard.writeString("Copied selection") }
        )

        let result = try await service.capture(from: context)

        XCTAssertEqual(result.text, "Copied selection")
        XCTAssertEqual(result.sourceApplication, context.captureSource)
        XCTAssertEqual(pasteboard.readString(), "Previous clipboard")
    }

    @MainActor
    func testMissingAccessibilityPermissionRemainsAnActionableError() async {
        let accessibility = SelectionTestAccessibility(selection: .empty)
        accessibility.isAuthorized = false
        let service = SelectedTextCaptureService(
            pasteboard: SelectionTestPasteboard(text: "Previous clipboard"),
            accessibility: accessibility,
            postCopy: { XCTFail("Unauthorized capture must not copy"); return false }
        )

        do {
            _ = try await service.capture(from: context)
            XCTFail("Expected missing Accessibility permission")
        } catch {
            XCTAssertEqual(error as? SelectedTextCaptureError, .accessibilityRequired)
        }
    }

    private var context: DestinationApplicationContext {
        DestinationApplicationContext(
            processIdentifier: ProcessInfo.processInfo.processIdentifier,
            name: "Example",
            bundleIdentifier: "com.example.app"
        )
    }
}

@MainActor
private final class SelectionTestAccessibility: SelectionAccessibilityReading {
    var isAuthorized = true
    let result: AccessibilitySelection

    init(selection: AccessibilitySelection) { result = selection }

    func selection(from context: DestinationApplicationContext) -> AccessibilitySelection { result }
}

@MainActor
private final class SelectionTestPasteboard: PasteboardAccessing {
    private var text: String
    private(set) var changeCount = 0

    init(text: String) { self.text = text }

    func snapshot() -> ClipboardSnapshot {
        ClipboardSnapshot(items: [ClipboardItemSnapshot(values: ["public.utf8-plain-text": Data(text.utf8)])])
    }

    func writeString(_ text: String) -> Bool {
        self.text = text
        changeCount += 1
        return true
    }

    func readString() -> String? { text }

    func restore(_ snapshot: ClipboardSnapshot) -> Bool {
        guard let data = snapshot.items.first?.values["public.utf8-plain-text"],
              let text = String(data: data, encoding: .utf8) else { return false }
        return writeString(text)
    }
}
