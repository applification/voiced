import CoreGraphics
import XCTest
@testable import Voiced

final class DoubleShiftGestureRecognizerTests: XCTestCase {
    func testRecognizesTwoCompletedShiftTaps() {
        var recognizer = DoubleShiftGestureRecognizer(maximumInterval: 0.36)

        XCTAssertFalse(recognizer.register(type: .flagsChanged, keyCode: 56, flags: .maskShift, timestamp: 1.00))
        XCTAssertFalse(recognizer.register(type: .flagsChanged, keyCode: 56, flags: [], timestamp: 1.05))
        XCTAssertFalse(recognizer.register(type: .flagsChanged, keyCode: 60, flags: .maskShift, timestamp: 1.25))
        XCTAssertTrue(recognizer.register(type: .flagsChanged, keyCode: 60, flags: [], timestamp: 1.30))
    }

    func testHoldingShiftIsNotACaptureTap() {
        var recognizer = DoubleShiftGestureRecognizer()

        XCTAssertFalse(recognizer.register(type: .flagsChanged, keyCode: 56, flags: .maskShift, timestamp: 1.00))
        XCTAssertFalse(recognizer.register(type: .flagsChanged, keyCode: 56, flags: [], timestamp: 2.00))
        XCTAssertFalse(recognizer.register(type: .flagsChanged, keyCode: 56, flags: .maskShift, timestamp: 2.10))
        XCTAssertFalse(recognizer.register(type: .flagsChanged, keyCode: 56, flags: [], timestamp: 2.15))
    }

    func testRejectsSlowOrModifiedSequence() {
        var recognizer = DoubleShiftGestureRecognizer(maximumInterval: 0.30)
        _ = recognizer.register(type: .flagsChanged, keyCode: 56, flags: .maskShift, timestamp: 1.00)
        _ = recognizer.register(type: .flagsChanged, keyCode: 56, flags: [], timestamp: 1.05)
        XCTAssertFalse(recognizer.register(type: .flagsChanged, keyCode: 56, flags: .maskShift, timestamp: 1.50))

        recognizer.reset()
        _ = recognizer.register(type: .flagsChanged, keyCode: 56, flags: [.maskShift, .maskCommand], timestamp: 2.00)
        _ = recognizer.register(type: .flagsChanged, keyCode: 56, flags: [], timestamp: 2.05)
        XCTAssertFalse(recognizer.register(type: .flagsChanged, keyCode: 56, flags: .maskShift, timestamp: 2.10))
    }

    func testTypingBreaksGestureDuringEitherTapOrBetweenTaps() {
        for keyTimestamp in [1.02, 1.10, 1.22] {
            var recognizer = DoubleShiftGestureRecognizer()
            let shiftEvents: [(TimeInterval, CGEventFlags)] = [
                (1.00, .maskShift), (1.05, []), (1.20, .maskShift), (1.25, [])
            ]
            var events = shiftEvents.map { (time: $0.0, type: CGEventType.flagsChanged, key: CGKeyCode(56), flags: $0.1) }
            events.append((time: keyTimestamp, type: .keyDown, key: 0, flags: .maskShift))
            for event in events.sorted(by: { $0.time < $1.time }) {
                XCTAssertFalse(recognizer.register(type: event.type, keyCode: event.key, flags: event.flags, timestamp: event.time))
            }
        }
    }

    func testOtherModifierBetweenTapsBreaksGesture() {
        var recognizer = DoubleShiftGestureRecognizer()
        _ = recognizer.register(type: .flagsChanged, keyCode: 56, flags: .maskShift, timestamp: 1.00)
        _ = recognizer.register(type: .flagsChanged, keyCode: 56, flags: [], timestamp: 1.05)
        _ = recognizer.register(type: .flagsChanged, keyCode: 55, flags: .maskCommand, timestamp: 1.10)
        _ = recognizer.register(type: .flagsChanged, keyCode: 55, flags: [], timestamp: 1.15)
        XCTAssertFalse(recognizer.register(type: .flagsChanged, keyCode: 56, flags: .maskShift, timestamp: 1.20))
        XCTAssertFalse(recognizer.register(type: .flagsChanged, keyCode: 56, flags: [], timestamp: 1.25))
    }

    func testLongSecondHoldDoesNotCaptureAndClearsSequence() {
        var recognizer = DoubleShiftGestureRecognizer()
        _ = recognizer.register(type: .flagsChanged, keyCode: 56, flags: .maskShift, timestamp: 1.00)
        _ = recognizer.register(type: .flagsChanged, keyCode: 56, flags: [], timestamp: 1.05)
        XCTAssertFalse(recognizer.register(type: .flagsChanged, keyCode: 56, flags: .maskShift, timestamp: 1.20))
        XCTAssertFalse(recognizer.register(type: .flagsChanged, keyCode: 56, flags: [], timestamp: 2.00))
        XCTAssertFalse(recognizer.register(type: .flagsChanged, keyCode: 56, flags: .maskShift, timestamp: 2.10))
        XCTAssertFalse(recognizer.register(type: .flagsChanged, keyCode: 56, flags: [], timestamp: 2.15))
    }
}
