import CoreGraphics
import XCTest
@testable import Voiced

final class VoiceCaptureDestinationTests: XCTestCase {
    func testCommandShiftSpaceDefaultsToFocusedEditorInsertion() {
        XCTAssertEqual(
            VoiceCaptureDestination.resolve(from: [.maskCommand, .maskShift]),
            .focusedEditor
        )
    }

    func testAddingOptionSelectsShelfCapture() {
        XCTAssertEqual(
            VoiceCaptureDestination.resolve(from: [.maskCommand, .maskShift, .maskAlternate]),
            .shelf
        )
    }
}

final class PushToTalkHotkeyTests: XCTestCase {
    private let modifiers: CGEventFlags = [.maskCommand, .maskShift]

    func testHoldStartsOnceAndSpaceReleaseStops() {
        var shortcut = PushToTalkHotkey()
        XCTAssertEqual(shortcut.register(type: .keyDown, keyCode: 49, flags: modifiers), .pressed)
        XCTAssertNil(shortcut.register(type: .keyDown, keyCode: 49, flags: modifiers))
        XCTAssertEqual(shortcut.register(type: .keyUp, keyCode: 49, flags: modifiers), .released)
        XCTAssertNil(shortcut.register(type: .keyUp, keyCode: 49, flags: []))
    }

    func testReleasingEitherModifierStopsWithoutRestartingOnRepeat() {
        for remaining: CGEventFlags in [.maskCommand, .maskShift] {
            var shortcut = PushToTalkHotkey()
            _ = shortcut.register(type: .keyDown, keyCode: 49, flags: modifiers)
            XCTAssertEqual(shortcut.register(type: .flagsChanged, keyCode: 56, flags: remaining), .released)
            XCTAssertNil(shortcut.register(type: .keyDown, keyCode: 49, flags: modifiers))
            XCTAssertNil(shortcut.register(type: .keyUp, keyCode: 49, flags: []))
            XCTAssertEqual(shortcut.register(type: .keyDown, keyCode: 49, flags: modifiers), .pressed)
        }
    }

    func testPlainCommandAndUnrelatedShortcutsDoNotRecord() {
        var shortcut = PushToTalkHotkey()
        XCTAssertNil(shortcut.register(type: .flagsChanged, keyCode: 54, flags: .maskCommand))
        XCTAssertNil(shortcut.register(type: .flagsChanged, keyCode: 54, flags: modifiers))
        XCTAssertNil(shortcut.register(type: .keyDown, keyCode: 49, flags: .maskCommand))
        XCTAssertNil(shortcut.register(type: .keyDown, keyCode: 49, flags: .maskAlternate))
        XCTAssertNil(shortcut.register(type: .keyDown, keyCode: 49, flags: [.maskCommand, .maskShift, .maskControl]))
        XCTAssertNil(shortcut.register(type: .keyDown, keyCode: 0, flags: modifiers))
    }

    func testOptionVariantAndCapsLockStillAllowRecording() {
        for additional: CGEventFlags in [.maskAlternate, .maskAlphaShift] {
            var shortcut = PushToTalkHotkey()
            XCTAssertEqual(shortcut.register(type: .keyDown, keyCode: 49, flags: modifiers.union(additional)), .pressed)
        }
    }

    func testUnrelatedKeyReleaseDoesNotStopRecording() {
        var shortcut = PushToTalkHotkey()
        _ = shortcut.register(type: .keyDown, keyCode: 49, flags: modifiers)
        XCTAssertNil(shortcut.register(type: .keyUp, keyCode: 0, flags: modifiers))
        XCTAssertEqual(shortcut.register(type: .keyUp, keyCode: 49, flags: []), .released)
    }

    func testFilterConsumesShortcutAndReleaseAfterModifiersLift() {
        let filter = PushToTalkEventFilter()
        XCTAssertTrue(filter.shouldConsume(type: .keyDown, keyCode: 49, flags: modifiers))
        XCTAssertFalse(filter.shouldConsume(type: .flagsChanged, keyCode: 56, flags: .maskCommand))
        XCTAssertTrue(filter.shouldConsume(type: .keyDown, keyCode: 49, flags: []))
        XCTAssertTrue(filter.shouldConsume(type: .keyUp, keyCode: 49, flags: []))
        XCTAssertFalse(filter.shouldConsume(type: .keyDown, keyCode: 49, flags: []))
    }

    func testFilterPassesThroughOrdinaryTypingAndShelfShortcut() {
        let filter = PushToTalkEventFilter()
        XCTAssertFalse(filter.shouldConsume(type: .keyDown, keyCode: 49, flags: []))
        XCTAssertFalse(filter.shouldConsume(type: .keyUp, keyCode: 49, flags: []))
        XCTAssertFalse(filter.shouldConsume(type: .keyDown, keyCode: 49, flags: .maskAlternate))
        XCTAssertFalse(filter.shouldConsume(type: .keyDown, keyCode: 0, flags: modifiers))
    }
}
