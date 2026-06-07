import CoreGraphics

enum PushToTalkHotkey: String, CaseIterable, Identifiable {
    case rightCommand
    case rightOption
    case rightControl
    case rightShift

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rightCommand: "Right Command"
        case .rightOption: "Right Option"
        case .rightControl: "Right Control"
        case .rightShift: "Right Shift"
        }
    }

    var onboardingLabel: String {
        switch self {
        case .rightCommand: "Right \u{2318}"
        case .rightOption: "Right \u{2325}"
        case .rightControl: "Right \u{2303}"
        case .rightShift: "Right \u{21E7}"
        }
    }

    var menuTitle: String {
        "Hold \(label) to Record"
    }

    var keyCode: CGKeyCode {
        switch self {
        case .rightCommand: 54
        case .rightOption: 61
        case .rightControl: 62
        case .rightShift: 60
        }
    }

    var eventFlag: CGEventFlags {
        switch self {
        case .rightCommand: .maskCommand
        case .rightOption: .maskAlternate
        case .rightControl: .maskControl
        case .rightShift: .maskShift
        }
    }
}
