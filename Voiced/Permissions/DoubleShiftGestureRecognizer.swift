import CoreGraphics
import Foundation

struct DoubleShiftGestureRecognizer {
    private let maximumInterval: TimeInterval
    private var isShiftDown = false
    private var lastShiftRelease: TimeInterval?

    init(maximumInterval: TimeInterval = 0.36) {
        self.maximumInterval = maximumInterval
    }

    mutating func register(
        keyCode: CGKeyCode,
        isPressed: Bool,
        hasOtherModifiers: Bool,
        timestamp: TimeInterval
    ) -> Bool {
        guard keyCode == 56 || keyCode == 60 else { return false }

        if hasOtherModifiers {
            reset()
            return false
        }

        if isPressed {
            guard !isShiftDown else { return false }
            isShiftDown = true
            if let lastShiftRelease,
               timestamp >= lastShiftRelease,
               timestamp - lastShiftRelease <= maximumInterval {
                self.lastShiftRelease = nil
                return true
            }
            return false
        }

        guard isShiftDown else { return false }
        isShiftDown = false
        lastShiftRelease = timestamp
        return false
    }

    mutating func reset() {
        isShiftDown = false
        lastShiftRelease = nil
    }
}
