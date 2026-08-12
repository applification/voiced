import Cocoa
@preconcurrency import ApplicationServices
import os

@MainActor
final class HotkeyManager {
    private static let logger = Logger(subsystem: "net.applification.voiced", category: "global-input")

    typealias KeyHandler = (_ type: CGEventType, _ keyCode: CGKeyCode, _ flags: CGEventFlags) -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: KeyHandler?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private(set) var isUsingEventTap = false

    func startListening(handler: @escaping KeyHandler) {
        stopListening()
        self.handler = handler

        let mask = (CGEventMask(1) << CGEventMask(CGEventType.flagsChanged.rawValue))
            | (CGEventMask(1) << CGEventMask(CGEventType.keyDown.rawValue))

        func makeTap(_ location: CGEventTapLocation) -> CFMachPort? {
            CGEvent.tapCreate(
                tap: location,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: mask,
                callback: { _, type, event, refcon in
                    guard let refcon else { return Unmanaged.passUnretained(event) }
                    let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                    let flags = event.flags
                    Task { @MainActor in
                        manager.handleEvent(type: type, keyCode: keyCode, flags: flags)
                    }
                    return Unmanaged.passUnretained(event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        }

        let tap = makeTap(.cgSessionEventTap) ?? makeTap(.cghidEventTap)
        if let tap {
            eventTap = tap
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            if let runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            }
            CGEvent.tapEnable(tap: tap, enable: true)
            isUsingEventTap = true
            Self.logger.info("Global input event tap enabled")
        } else {
            installNSEventFallback()
            Self.logger.warning("Global input event tap unavailable; NSEvent fallback installed")
        }
    }

    func stopListening() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
        isUsingEventTap = false

        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        handler = nil
    }

    private func handleEvent(type: CGEventType, keyCode: CGKeyCode, flags: CGEventFlags) {
        guard type == .flagsChanged || type == .keyDown else { return }
        handler?(type, keyCode, flags)
    }

    private func installNSEventFallback() {
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
            return event
        }
    }

    private func handle(_ event: NSEvent) {
        let type: CGEventType = event.type == .flagsChanged ? .flagsChanged : .keyDown
        handleEvent(
            type: type,
            keyCode: CGKeyCode(event.keyCode),
            flags: Self.cgFlags(from: event.modifierFlags)
        )
    }

    private static func cgFlags(from flags: NSEvent.ModifierFlags) -> CGEventFlags {
        var result: CGEventFlags = []
        if flags.contains(.command) { result.insert(.maskCommand) }
        if flags.contains(.option) { result.insert(.maskAlternate) }
        if flags.contains(.control) { result.insert(.maskControl) }
        if flags.contains(.shift) { result.insert(.maskShift) }
        return result
    }
}
