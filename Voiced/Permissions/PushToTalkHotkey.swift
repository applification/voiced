import CoreGraphics
import Foundation

struct PushToTalkHotkey {
    enum Transition: Equatable {
        case pressed
        case released
    }

    static let keyCode: CGKeyCode = 49
    static let requiredModifiers: CGEventFlags = [.maskCommand, .maskShift]

    private(set) var isHoldingSpace = false
    private var isActive = false

    static func matches(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        keyCode == Self.keyCode
            && flags.contains(requiredModifiers)
            && !flags.contains(.maskControl)
    }

    mutating func register(type: CGEventType, keyCode: CGKeyCode, flags: CGEventFlags) -> Transition? {
        if type == .keyUp, keyCode == Self.keyCode {
            isHoldingSpace = false
            guard isActive else { return nil }
            isActive = false
            return .released
        }

        if type == .flagsChanged, isActive, !flags.contains(Self.requiredModifiers) {
            isActive = false
            return .released
        }

        guard type == .keyDown,
              !isHoldingSpace,
              Self.matches(keyCode: keyCode, flags: flags) else { return nil }
        isHoldingSpace = true
        isActive = true
        return .pressed
    }
}

// Event tap callbacks must decide synchronously whether to pass the key through.
// Keep this state separate from the coordinator and protect it across callbacks.
final class PushToTalkEventFilter: @unchecked Sendable {
    private let lock = NSLock()
    private var shortcut = PushToTalkHotkey()

    func shouldConsume(type: CGEventType, keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let wasHoldingSpace = shortcut.isHoldingSpace
        _ = shortcut.register(type: type, keyCode: keyCode, flags: flags)
        return keyCode == PushToTalkHotkey.keyCode
            && (type == .keyDown || type == .keyUp)
            && (wasHoldingSpace || shortcut.isHoldingSpace)
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        shortcut = PushToTalkHotkey()
    }
}
