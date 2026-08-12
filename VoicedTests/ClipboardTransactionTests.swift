import XCTest
@testable import Voiced

@MainActor
final class ClipboardTransactionTests: XCTestCase {
    func testRestoresSnapshotWhenClipboardDidNotChange() {
        let original = ClipboardSnapshot(items: [
            ClipboardItemSnapshot(values: ["public.utf8-plain-text": Data("before".utf8)])
        ])
        let pasteboard = FakePasteboard(snapshot: original)

        let transaction = ClipboardTransaction.replacingText("temporary", on: pasteboard)

        XCTAssertNotNil(transaction)
        XCTAssertTrue(transaction!.restoreIfUnchanged(on: pasteboard))
        XCTAssertEqual(pasteboard.currentSnapshot, original)
    }

    func testDoesNotOverwriteClipboardChangedByAnotherApp() {
        let original = ClipboardSnapshot(items: [
            ClipboardItemSnapshot(values: ["public.utf8-plain-text": Data("before".utf8)])
        ])
        let pasteboard = FakePasteboard(snapshot: original)
        let transaction = ClipboardTransaction.replacingText("temporary", on: pasteboard)!

        pasteboard.simulateExternalChange(to: "new user clipboard")

        XCTAssertFalse(transaction.restoreIfUnchanged(on: pasteboard))
        XCTAssertEqual(pasteboard.readString(), "new user clipboard")
    }
}

@MainActor
private final class FakePasteboard: PasteboardAccessing {
    private(set) var changeCount = 1
    private(set) var currentSnapshot: ClipboardSnapshot
    private var currentString: String?

    init(snapshot: ClipboardSnapshot) {
        currentSnapshot = snapshot
    }

    func snapshot() -> ClipboardSnapshot { currentSnapshot }

    func writeString(_ text: String) -> Bool {
        currentString = text
        currentSnapshot = ClipboardSnapshot(items: [
            ClipboardItemSnapshot(values: ["public.utf8-plain-text": Data(text.utf8)])
        ])
        changeCount += 1
        return true
    }

    func readString() -> String? { currentString }

    func restore(_ snapshot: ClipboardSnapshot) -> Bool {
        currentSnapshot = snapshot
        currentString = nil
        changeCount += 1
        return true
    }

    func simulateExternalChange(to text: String) {
        _ = writeString(text)
    }
}
