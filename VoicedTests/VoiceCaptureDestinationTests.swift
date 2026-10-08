import CoreGraphics
import XCTest
@testable import Voiced

final class VoiceCaptureDestinationTests: XCTestCase {
    func testControlOptionZDefaultsToFocusedEditorInsertion() {
        XCTAssertEqual(
            VoiceCaptureDestination.resolve(from: [.maskControl, .maskAlternate]),
            .focusedEditor
        )
    }

    func testAddingShiftSelectsShelfCapture() {
        XCTAssertEqual(
            VoiceCaptureDestination.resolve(from: [.maskControl, .maskAlternate, .maskShift]),
            .shelf
        )
    }
}

final class PushToTalkHotkeyTests: XCTestCase {
    private let modifiers: CGEventFlags = [.maskControl, .maskAlternate]

    func testHoldStartsOnceAndZReleaseStops() {
        var shortcut = PushToTalkHotkey()
        XCTAssertEqual(shortcut.register(type: .keyDown, keyCode: 6, flags: modifiers), .pressed)
        XCTAssertNil(shortcut.register(type: .keyDown, keyCode: 6, flags: modifiers))
        XCTAssertEqual(shortcut.register(type: .keyUp, keyCode: 6, flags: modifiers), .released)
        XCTAssertNil(shortcut.register(type: .keyUp, keyCode: 6, flags: []))
    }

    func testReleasingEitherModifierStopsWithoutRestartingOnRepeat() {
        for remaining: CGEventFlags in [.maskControl, .maskAlternate] {
            var shortcut = PushToTalkHotkey()
            _ = shortcut.register(type: .keyDown, keyCode: 6, flags: modifiers)
            XCTAssertEqual(shortcut.register(type: .flagsChanged, keyCode: 58, flags: remaining), .released)
            XCTAssertNil(shortcut.register(type: .keyDown, keyCode: 6, flags: modifiers))
            XCTAssertNil(shortcut.register(type: .keyUp, keyCode: 6, flags: []))
            XCTAssertEqual(shortcut.register(type: .keyDown, keyCode: 6, flags: modifiers), .pressed)
        }
    }

    func testPlainCommandAndUnrelatedShortcutsDoNotRecord() {
        var shortcut = PushToTalkHotkey()
        XCTAssertNil(shortcut.register(type: .flagsChanged, keyCode: 54, flags: .maskCommand))
        XCTAssertNil(shortcut.register(type: .flagsChanged, keyCode: 54, flags: modifiers))
        XCTAssertNil(shortcut.register(type: .keyDown, keyCode: 6, flags: .maskCommand))
        XCTAssertNil(shortcut.register(type: .keyDown, keyCode: 6, flags: []))
        XCTAssertNil(shortcut.register(type: .keyDown, keyCode: 6, flags: .maskControl))
        XCTAssertNil(shortcut.register(type: .keyDown, keyCode: 6, flags: .maskAlternate))
        XCTAssertNil(shortcut.register(type: .keyDown, keyCode: 6, flags: [.maskCommand, .maskShift, .maskControl]))
        XCTAssertNil(shortcut.register(type: .keyDown, keyCode: 0, flags: modifiers))
    }

    func testSiriShortcutPassesThroughWithoutRecording() {
        var shortcut = PushToTalkHotkey()
        let filter = PushToTalkEventFilter()
        let siriModifiers: CGEventFlags = [.maskCommand, .maskShift]
        XCTAssertNil(shortcut.register(type: .keyDown, keyCode: 49, flags: siriModifiers))
        XCTAssertFalse(filter.shouldConsume(type: .keyDown, keyCode: 49, flags: siriModifiers))
        XCTAssertFalse(filter.shouldConsume(type: .keyUp, keyCode: 49, flags: siriModifiers))
    }

    func testSystemAndPreviousSpaceShortcutsPassThrough() {
        for flags: CGEventFlags in [.maskControl, [.maskControl, .maskShift], [.maskControl, .maskAlternate, .maskShift]] {
            var shortcut = PushToTalkHotkey()
            let filter = PushToTalkEventFilter()
            XCTAssertNil(shortcut.register(type: .keyDown, keyCode: 49, flags: flags))
            XCTAssertFalse(filter.shouldConsume(type: .keyDown, keyCode: 49, flags: flags))
            XCTAssertFalse(filter.shouldConsume(type: .keyUp, keyCode: 49, flags: flags))
        }
    }

    func testOptionZStillTypesOmegaWithoutRecording() {
        var shortcut = PushToTalkHotkey()
        let filter = PushToTalkEventFilter()
        XCTAssertNil(shortcut.register(type: .keyDown, keyCode: 6, flags: .maskAlternate))
        XCTAssertFalse(filter.shouldConsume(type: .keyDown, keyCode: 6, flags: .maskAlternate))
        XCTAssertFalse(filter.shouldConsume(type: .keyUp, keyCode: 6, flags: .maskAlternate))
    }

    func testShiftVariantAndCapsLockStillAllowRecording() {
        for additional: CGEventFlags in [.maskShift, .maskAlphaShift] {
            var shortcut = PushToTalkHotkey()
            XCTAssertEqual(shortcut.register(type: .keyDown, keyCode: 6, flags: modifiers.union(additional)), .pressed)
        }
    }

    func testUnrelatedKeyReleaseDoesNotStopRecording() {
        var shortcut = PushToTalkHotkey()
        _ = shortcut.register(type: .keyDown, keyCode: 6, flags: modifiers)
        XCTAssertNil(shortcut.register(type: .keyUp, keyCode: 0, flags: modifiers))
        XCTAssertEqual(shortcut.register(type: .keyUp, keyCode: 6, flags: []), .released)
    }

    func testFilterConsumesShortcutAndReleaseAfterModifiersLift() {
        let filter = PushToTalkEventFilter()
        XCTAssertTrue(filter.shouldConsume(type: .keyDown, keyCode: 6, flags: modifiers))
        XCTAssertFalse(filter.shouldConsume(type: .flagsChanged, keyCode: 58, flags: []))
        XCTAssertTrue(filter.shouldConsume(type: .keyDown, keyCode: 6, flags: []))
        XCTAssertTrue(filter.shouldConsume(type: .keyUp, keyCode: 6, flags: []))
        XCTAssertFalse(filter.shouldConsume(type: .keyDown, keyCode: 6, flags: []))
    }

    func testFilterPassesThroughOrdinaryTypingAndShelfShortcut() {
        let filter = PushToTalkEventFilter()
        XCTAssertFalse(filter.shouldConsume(type: .keyDown, keyCode: 6, flags: []))
        XCTAssertFalse(filter.shouldConsume(type: .keyUp, keyCode: 6, flags: []))
        XCTAssertFalse(filter.shouldConsume(type: .keyDown, keyCode: 49, flags: .maskAlternate))
        XCTAssertFalse(filter.shouldConsume(type: .keyDown, keyCode: 0, flags: modifiers))
    }
}
