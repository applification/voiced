import CoreGraphics
import Foundation

struct DoubleShiftGestureRecognizer {
    private let maximumInterval: TimeInterval
    private let maximumTapDuration: TimeInterval
    private var shiftPress: (keyCode: CGKeyCode, timestamp: TimeInterval)?
    private var lastShiftRelease: TimeInterval?

    init(maximumInterval: TimeInterval = 0.36, maximumTapDuration: TimeInterval = 0.25) {
        self.maximumInterval = maximumInterval
        self.maximumTapDuration = maximumTapDuration
    }

    mutating func register(
        type: CGEventType,
        keyCode: CGKeyCode,
        flags: CGEventFlags,
        timestamp: TimeInterval
    ) -> Bool {
        // Typing or any other modifier breaks the gesture, including keys used
        // during either Shift hold. A capital letter is never a capture tap.
        if type == .keyDown {
            reset()
            return false
        }
        guard type == .flagsChanged else { return false }

        guard (keyCode == 56 || keyCode == 60),
              flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskSecondaryFn]).isEmpty else {
            reset()
            return false
        }

        if flags.contains(.maskShift) {
            guard shiftPress == nil else {
                reset()
                return false
            }
            shiftPress = (keyCode, timestamp)
            return false
        }

        guard let press = shiftPress, press.keyCode == keyCode,
              timestamp >= press.timestamp,
              timestamp - press.timestamp <= maximumTapDuration else {
            reset()
            return false
        }
        shiftPress = nil
        if let lastShiftRelease,
           press.timestamp >= lastShiftRelease,
           press.timestamp - lastShiftRelease <= maximumInterval {
            self.lastShiftRelease = nil
            return true
        }
        lastShiftRelease = timestamp
        return false
    }

    mutating func reset() {
        shiftPress = nil
        lastShiftRelease = nil
    }
}
