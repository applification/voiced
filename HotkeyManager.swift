import Cocoa
@preconcurrency import ApplicationServices
import os

@MainActor
final class HotkeyManager {
    private static let logger = Logger(subsystem: "com.voiced.app", category: "hotkeys")
    private var promptedAX: Bool = false

    typealias KeyHandler = (_ type: CGEventType, _ keyCode: CGKeyCode, _ flags: CGEventFlags) -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: KeyHandler?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func startListening(handler: @escaping KeyHandler) {
        self.handler = handler

        let accessibilityTrusted = AXIsProcessTrustedWithOptions(nil)
        HotkeyManager.logger.info("Accessibility trusted: \(accessibilityTrusted, privacy: .public)")

        let mask: CGEventMask = (
            (CGEventMask(1) << CGEventMask(CGEventType.keyDown.rawValue)) |
            (CGEventMask(1) << CGEventMask(CGEventType.keyUp.rawValue)) |
            (CGEventMask(1) << CGEventMask(CGEventType.flagsChanged.rawValue))
        )

        func makeTap(_ location: CGEventTapLocation) -> CFMachPort? {
            return CGEvent.tapCreate(tap: location,
                                     place: .headInsertEventTap,
                                     options: .defaultTap,
                                     eventsOfInterest: mask,
                                     callback: { proxy, type, event, refcon in
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(refcon!).takeUnretainedValue()
                HotkeyManager.logger.debug("Event type: \(type.rawValue, privacy: .public), keyCode: \(keyCode, privacy: .public), flags: \(UInt64(flags.rawValue), privacy: .public)")
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
            // Fallback: Use NSEvent global and local monitors as a best-effort capture.
            let masks: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged]
            self.globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: masks) { [weak self] event in
                guard let self else { return }
                let type: CGEventType
                switch event.type {
                case .keyDown: type = .keyDown
                case .keyUp: type = .keyUp
                case .flagsChanged: type = .flagsChanged
                default: return
                }
                let keyCode = CGKeyCode(event.keyCode)
                let flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
                HotkeyManager.logger.debug("NSEvent monitor type: \(type.rawValue, privacy: .public), keyCode: \(keyCode, privacy: .public), flags: \(UInt64(flags.rawValue), privacy: .public)")
                self.handler?(type, keyCode, flags)
            }
            // Local monitor to also catch events when the app is key.
            self.localMonitor = NSEvent.addLocalMonitorForEvents(matching: masks) { [weak self] event in
                guard let self else { return event }
                let type: CGEventType
                switch event.type {
                case .keyDown: type = .keyDown
                case .keyUp: type = .keyUp
                case .flagsChanged: type = .flagsChanged
                default: return event
                }
                let keyCode = CGKeyCode(event.keyCode)
                let flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
                HotkeyManager.logger.debug("NSEvent local monitor type: \(type.rawValue, privacy: .public), keyCode: \(keyCode, privacy: .public), flags: \(UInt64(flags.rawValue), privacy: .public)")
                self.handler?(type, keyCode, flags)
                return event
            }
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
}
