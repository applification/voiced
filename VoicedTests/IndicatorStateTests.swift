import XCTest
@testable import Voiced

final class IndicatorStateTests: XCTestCase {
    func testAccessibilityLabelsDescribeStatus() {
        XCTAssertEqual(IndicatorState.recording(level: 0.3).accessibilityLabel, "Recording")
        XCTAssertEqual(IndicatorState.transcribing.accessibilityLabel, "Transcribing")
        XCTAssertEqual(IndicatorState.processing.accessibilityLabel, "Processing")
        XCTAssertEqual(IndicatorState.success("Saved to Inbox").accessibilityLabel, "Saved to Inbox")
        XCTAssertEqual(IndicatorState.error("Insert failed").accessibilityLabel, "Error: Insert failed")
    }
}
