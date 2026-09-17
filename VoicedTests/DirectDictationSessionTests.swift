import XCTest
@testable import Voiced

@MainActor
final class DirectDictationSessionTests: XCTestCase {
    func testDraftAndRefinementReplaceOnlyOriginalSelectionIncludingUnicode() throws {
        let target = TestTextTarget(text: "👋 Before old after", selection: NSRange(location: 10, length: 3))
        let session = try XCTUnwrap(DirectDictationSession(target: target))
        XCTAssertTrue(session.update("um new"))
        XCTAssertEqual(target.text, "👋 Before um new after")
        XCTAssertTrue(session.update("New."))
        XCTAssertEqual(target.text, "👋 Before New. after")
    }

    func testUserEditStopsAllFurtherReplacement() throws {
        let target = TestTextTarget(text: "Hello ", selection: NSRange(location: 6, length: 0))
        let session = try XCTUnwrap(DirectDictationSession(target: target))
        XCTAssertTrue(session.update("world"))
        target.text = "Hello world! edited"
        XCTAssertFalse(session.update("Refined"))
        XCTAssertFalse(session.cancel())
        XCTAssertEqual(target.text, "Hello world! edited")
    }

    func testMovingCaretOrFocusStopsReplacement() throws {
        for moveFocus in [false, true] {
            let target = TestTextTarget(text: "prefix", selection: NSRange(location: 6, length: 0))
            let session = try XCTUnwrap(DirectDictationSession(target: target))
            XCTAssertTrue(session.update(" draft"))
            if moveFocus { target.isFocused = false } else { target.selection = NSRange(location: 0, length: 0) }
            XCTAssertFalse(session.update("final"))
            XCTAssertEqual(target.text, "prefix draft")
        }
    }

    func testCancelRestoresOriginalTextAndSelection() throws {
        let target = TestTextTarget(text: "keep replace keep", selection: NSRange(location: 5, length: 7))
        let session = try XCTUnwrap(DirectDictationSession(target: target))
        XCTAssertTrue(session.update("draft"))
        XCTAssertTrue(session.cancel())
        XCTAssertEqual(target.text, "keep replace keep")
        XCTAssertEqual(target.selection, NSRange(location: 5, length: 7))
    }

    func testFailedWriteCannotBeRetriedOverUnknownFieldState() throws {
        let target = TestTextTarget(text: "", selection: NSRange(location: 0, length: 0))
        let session = try XCTUnwrap(DirectDictationSession(target: target))
        target.acceptWrites = false
        XCTAssertFalse(session.update("draft"))
        XCTAssertTrue(session.hasAttemptedWrite)
        target.acceptWrites = true
        XCTAssertFalse(session.update("final"))
        XCTAssertEqual(target.text, "")
    }
}

@MainActor
private final class TestTextTarget: DictationTextTarget {
    var isFocused = true
    var text: String?
    var selection: NSRange?
    var acceptWrites = true
    init(text: String, selection: NSRange) { self.text = text; self.selection = selection }
    func replaceText(_ text: String, selection: NSRange) -> Bool {
        guard acceptWrites else { return false }
        self.text = text
        self.selection = selection
        return true
    }
}
