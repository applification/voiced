import Cocoa

@MainActor
final class HotkeyManager {
    private static let escapeKeyCode: CGKeyCode = 53

    typealias KeyHandler = (_ type: CGEventType, _ keyCode: CGKeyCode, _ flags: CGEventFlags) -> Void

    private var handler: KeyHandler?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func startListening(handler: @escaping KeyHandler) {
        self.handler = handler
        installNSEventMonitors()
    }

    func stopListening() {
        handler = nil
        if let gm = globalMonitor { NSEvent.removeMonitor(gm) }
        if let lm = localMonitor { NSEvent.removeMonitor(lm) }
        globalMonitor = nil
        localMonitor = nil
    }

    private static func cgEventFlags(from modifierFlags: NSEvent.ModifierFlags) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifierFlags.contains(.command) {
            flags.insert(.maskCommand)
        }
        if modifierFlags.contains(.option) {
            flags.insert(.maskAlternate)
        }
        if modifierFlags.contains(.control) {
            flags.insert(.maskControl)
        }
        if modifierFlags.contains(.shift) {
            flags.insert(.maskShift)
        }
        return flags
    }

    private func installNSEventMonitors() {
        let masks: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: masks) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: masks) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    private func handle(_ event: NSEvent) {
        guard event.type == .flagsChanged || event.type == .keyDown else { return }
        let keyCode = CGKeyCode(event.keyCode)
        if event.type == .keyDown && keyCode != Self.escapeKeyCode { return }

        let flags = Self.cgEventFlags(from: event.modifierFlags)
        handler?(event.type == .keyDown ? .keyDown : .flagsChanged, keyCode, flags)
    }
}
