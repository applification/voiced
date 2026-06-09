import Cocoa
@preconcurrency import ApplicationServices
import os
import Security

@MainActor
final class HotkeyManager {
    private static let logger = Logger(subsystem: "net.applification.voiced", category: "hotkeys")
    private static let escapeKeyCode: CGKeyCode = 53

    typealias KeyHandler = (_ type: CGEventType, _ keyCode: CGKeyCode, _ flags: CGEventFlags) -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: KeyHandler?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func startListening(handler: @escaping KeyHandler) {
        self.handler = handler

        if Self.isAppSandboxed {
            HotkeyManager.logger.info("App Sandbox detected; using NSEvent fallback monitors")
            installNSEventFallback()
            return
        }

        let mask = (CGEventMask(1) << CGEventMask(CGEventType.flagsChanged.rawValue))
            | (CGEventMask(1) << CGEventMask(CGEventType.keyDown.rawValue))

        func makeTap(_ location: CGEventTapLocation) -> CFMachPort? {
            return CGEvent.tapCreate(tap: location,
                                     place: .headInsertEventTap,
                                     options: .defaultTap,
	                                     eventsOfInterest: mask,
	                                     callback: { proxy, type, event, refcon in
	                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
	                if type == .keyDown && CGKeyCode(keyCode) != HotkeyManager.escapeKeyCode {
	                    return Unmanaged.passUnretained(event)
	                }
	                let flags = event.flags
	                let mgr = Unmanaged<HotkeyManager>.fromOpaque(refcon!).takeUnretainedValue()
	                if type == .flagsChanged {
	                    HotkeyManager.logger.debug("Modifier event keyCode: \(keyCode, privacy: .public), flags: \(UInt64(flags.rawValue), privacy: .public)")
	                } else {
	                    HotkeyManager.logger.debug("Escape key event")
	                }
	                mgr.handler?(type, CGKeyCode(keyCode), flags)
	                return Unmanaged.passUnretained(event)
	            },
                                     userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        }

        // Try session tap first, then HID tap as a fallback.
        var tap: CFMachPort? = makeTap(.cgSessionEventTap)
        if tap == nil {
            HotkeyManager.logger.warning("Failed to create cgSessionEventTap; trying cghidEventTap. This may require Input Monitoring permission.")
            tap = makeTap(.cghidEventTap)
        }
        if let tap {
            self.eventTap = tap
            self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), self.runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            HotkeyManager.logger.info("CGEvent tap enabled")
        } else {
            HotkeyManager.logger.warning("Failed to create CGEvent tap at both locations. Falling back to NSEvent monitors.")
            installNSEventFallback()
        }
    }

    func stopListening() {
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap = eventTap { CFMachPortInvalidate(tap) }
        runLoopSource = nil
        eventTap = nil
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

    private static var isAppSandboxed: Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(
                task,
                "com.apple.security.app-sandbox" as CFString,
                nil
              )
        else {
            return false
        }
        return (value as? Bool) == true
    }

    private func installNSEventFallback() {
        let masks: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
        self.globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: masks) { [weak self] event in
            guard let self else { return }
            guard event.type == .flagsChanged || event.type == .keyDown else { return }
            let keyCode = CGKeyCode(event.keyCode)
            if event.type == .keyDown && keyCode != Self.escapeKeyCode { return }
            let flags = Self.cgEventFlags(from: event.modifierFlags)
            if event.type == .flagsChanged {
                HotkeyManager.logger.debug("NSEvent global modifier keyCode: \(keyCode, privacy: .public), appKitFlags: \(UInt64(event.modifierFlags.rawValue), privacy: .public), cgFlags: \(UInt64(flags.rawValue), privacy: .public)")
            } else {
                HotkeyManager.logger.debug("NSEvent global Escape key")
            }
            self.handler?(event.type == .keyDown ? .keyDown : .flagsChanged, keyCode, flags)
        }
        self.localMonitor = NSEvent.addLocalMonitorForEvents(matching: masks) { [weak self] event in
            guard let self else { return event }
            guard event.type == .flagsChanged || event.type == .keyDown else { return event }
            let keyCode = CGKeyCode(event.keyCode)
            if event.type == .keyDown && keyCode != Self.escapeKeyCode { return event }
            let flags = Self.cgEventFlags(from: event.modifierFlags)
            if event.type == .flagsChanged {
                HotkeyManager.logger.debug("NSEvent local modifier keyCode: \(keyCode, privacy: .public), appKitFlags: \(UInt64(event.modifierFlags.rawValue), privacy: .public), cgFlags: \(UInt64(flags.rawValue), privacy: .public)")
            } else {
                HotkeyManager.logger.debug("NSEvent local Escape key")
            }
            self.handler?(event.type == .keyDown ? .keyDown : .flagsChanged, keyCode, flags)
            return event
        }
        HotkeyManager.logger.info("NSEvent fallback monitors installed")
    }
}
