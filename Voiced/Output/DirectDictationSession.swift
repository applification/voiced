import AppKit
import ApplicationServices

@MainActor
protocol DictationTextTarget: AnyObject {
    var isFocused: Bool { get }
    var text: String? { get }
    var selection: NSRange? { get }
    func replaceText(_ text: String, selection: NSRange) -> Bool
}

/// A checked transaction over one selection. Never deletes characters by counting
/// keystrokes: an unexpected value, caret or focus ends ownership of the draft.
@MainActor
final class DirectDictationSession {
    private let target: any DictationTextTarget
    private let originalText: String
    private let originalSelection: NSRange
    private let prefix: String
    private let suffix: String
    private var expectedText: String
    private var expectedSelection: NSRange
    private(set) var hasAttemptedWrite = false
    private(set) var lostOwnership = false

    init?(target: any DictationTextTarget) {
        guard target.isFocused, let text = target.text, let selection = target.selection,
              let range = Range(selection, in: text) else { return nil }
        self.target = target
        originalText = text
        originalSelection = selection
        expectedText = text
        expectedSelection = selection
        prefix = String(text[..<range.lowerBound])
        suffix = String(text[range.upperBound...])
    }

    private var ownsDraft: Bool {
        !lostOwnership && target.isFocused && target.text == expectedText && target.selection == expectedSelection
    }

    @discardableResult
    func update(_ draft: String) -> Bool {
        guard ownsDraft else { lostOwnership = true; return false }
        let text = prefix + draft + suffix
        guard text != expectedText else { return true }
        let selection = NSRange(location: (prefix + draft).utf16.count, length: 0)
        hasAttemptedWrite = true
        guard target.replaceText(text, selection: selection),
              target.text == text, target.selection == selection else {
            lostOwnership = true
            return false
        }
        expectedText = text
        expectedSelection = selection
        return true
    }

    @discardableResult
    func cancel() -> Bool {
        guard hasAttemptedWrite else { return true }
        guard ownsDraft else { lostOwnership = true; return false }
        return target.replaceText(originalText, selection: originalSelection)
    }
}

@MainActor
final class AccessibilityTextTarget: DictationTextTarget {
    let element: AXUIElement
    private let pid: pid_t

    init?(application: NSRunningApplication?) {
        guard AXIsProcessTrusted(), let application,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier,
              let element = Self.focusedElement() else { return nil }
        let role = Self.attribute(element, kAXRoleAttribute) as? String
        let subrole = Self.attribute(element, kAXSubroleAttribute) as? String
        guard [kAXTextFieldRole, kAXTextAreaRole].contains(role), subrole != kAXSecureTextFieldSubrole else { return nil }
        var valueSettable: DarwinBoolean = false
        var rangeSettable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &valueSettable) == .success,
              AXUIElementIsAttributeSettable(element, kAXSelectedTextRangeAttribute as CFString, &rangeSettable) == .success,
              valueSettable.boolValue, rangeSettable.boolValue else { return nil }
        self.element = element
        pid = application.processIdentifier
    }

    var isFocused: Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
              let focused = Self.focusedElement() else { return false }
        return CFEqual(focused, element)
    }

    var text: String? { Self.attribute(element, kAXValueAttribute) as? String }
    var selection: NSRange? { Self.selectedRange(element) }

    func replaceText(_ text: String, selection: NSRange) -> Bool {
        guard isFocused else { return false }
        guard AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFString) == .success else { return false }
        var range = CFRange(location: selection.location, length: selection.length)
        guard let value = AXValueCreate(.cfRange, &range) else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value) == .success
    }

    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    static func focusedElement() -> AXUIElement? {
        guard let value = attribute(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    static func selectedRange(_ element: AXUIElement) -> NSRange? {
        guard let value = attribute(element, kAXSelectedTextRangeAttribute),
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range), range.location >= 0, range.length >= 0 else { return nil }
        return NSRange(location: range.location, length: range.length)
    }

    static func caretPoint() -> NSPoint? {
        guard let element = focusedElement(), var range = selectedRange(element) else { return nil }
        range.length = 0
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let parameter = AXValueCreate(.cfRange, &cfRange) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, parameter, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var bounds = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &bounds), !bounds.isInfinite, bounds.height > 0 else { return nil }
        return NSPoint(x: bounds.minX, y: (NSScreen.screens.first?.frame.maxY ?? 0) - bounds.maxY)
    }
}

/// Preview insertion also stops if the user switches fields or changes the selection.
@MainActor
struct DictationInsertionAnchor {
    private let pid: pid_t?
    private let element: AXUIElement?
    private let text: String?
    private let selection: NSRange?

    init(application: NSRunningApplication?) {
        pid = application?.processIdentifier
        element = AccessibilityTextTarget.focusedElement()
        text = element.flatMap { AccessibilityTextTarget.attribute($0, kAXValueAttribute) as? String }
        selection = element.flatMap { AccessibilityTextTarget.selectedRange($0) }
    }

    var isUnchanged: Bool {
        guard let pid, NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return false }
        guard let element else { return true }
        guard let focused = AccessibilityTextTarget.focusedElement(), CFEqual(element, focused) else { return false }
        if let text, AccessibilityTextTarget.attribute(element, kAXValueAttribute) as? String != text { return false }
        if let selection, AccessibilityTextTarget.selectedRange(element) != selection { return false }
        return true
    }
}
