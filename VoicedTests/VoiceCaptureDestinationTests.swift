import CoreGraphics
import XCTest
@testable import Voiced

final class VoiceCaptureDestinationTests: XCTestCase {
    func testRightCommandDefaultsToFocusedEditorInsertion() {
        XCTAssertEqual(
            VoiceCaptureDestination.resolve(from: [.maskCommand]),
            .focusedEditor
        )
    }

    func testShiftRightCommandSelectsShelfCapture() {
        XCTAssertEqual(
            VoiceCaptureDestination.resolve(from: [.maskCommand, .maskShift]),
            .shelf
        )
    }
}
