import XCTest
@testable import Voiced

final class DoubleShiftGestureRecognizerTests: XCTestCase {
    func testRecognizesTwoCompletedShiftTaps() {
        var recognizer = DoubleShiftGestureRecognizer(maximumInterval: 0.36)

        XCTAssertFalse(recognizer.register(keyCode: 56, isPressed: true, hasOtherModifiers: false, timestamp: 1.00))
        XCTAssertFalse(recognizer.register(keyCode: 56, isPressed: false, hasOtherModifiers: false, timestamp: 1.05))
        XCTAssertTrue(recognizer.register(keyCode: 60, isPressed: true, hasOtherModifiers: false, timestamp: 1.25))
    }

    func testRejectsSlowOrModifiedSequence() {
        var recognizer = DoubleShiftGestureRecognizer(maximumInterval: 0.30)
        _ = recognizer.register(keyCode: 56, isPressed: true, hasOtherModifiers: false, timestamp: 1.00)
        _ = recognizer.register(keyCode: 56, isPressed: false, hasOtherModifiers: false, timestamp: 1.05)
        XCTAssertFalse(recognizer.register(keyCode: 56, isPressed: true, hasOtherModifiers: false, timestamp: 1.50))

        recognizer.reset()
        _ = recognizer.register(keyCode: 56, isPressed: true, hasOtherModifiers: true, timestamp: 2.00)
        _ = recognizer.register(keyCode: 56, isPressed: false, hasOtherModifiers: false, timestamp: 2.05)
        XCTAssertFalse(recognizer.register(keyCode: 56, isPressed: true, hasOtherModifiers: false, timestamp: 2.10))
    }
}
