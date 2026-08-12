import XCTest
@testable import Voiced

final class CaptureRelativeTimeLabelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testUsesMinuteGranularityForRecentCaptures() {
        XCTAssertEqual(CaptureRelativeTimeLabel.text(for: now.addingTimeInterval(-59), relativeTo: now), "Now")
        XCTAssertEqual(CaptureRelativeTimeLabel.text(for: now.addingTimeInterval(-60), relativeTo: now), "1m")
        XCTAssertEqual(CaptureRelativeTimeLabel.text(for: now.addingTimeInterval(-119), relativeTo: now), "1m")
        XCTAssertEqual(CaptureRelativeTimeLabel.text(for: now.addingTimeInterval(-120), relativeTo: now), "2m")
    }

    func testCompactsOlderCapturesWithoutSeconds() {
        XCTAssertEqual(CaptureRelativeTimeLabel.text(for: now.addingTimeInterval(-3_600), relativeTo: now), "1h")
        XCTAssertEqual(CaptureRelativeTimeLabel.text(for: now.addingTimeInterval(-86_400), relativeTo: now), "1d")
    }
}
