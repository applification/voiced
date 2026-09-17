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
    private var permissionRetryTask: Task<Void, Never>?
    private nonisolated let shortcutFilter = PushToTalkEventFilter()

    private(set) var isUsingEventTap = false

    func startListening(handler: @escaping KeyHandler) {
        stopListening()
        self.handler = handler

        let mask = (CGEventMask(1) << CGEventMask(CGEventType.flagsChanged.rawValue))
            | (CGEventMask(1) << CGEventMask(CGEventType.keyDown.rawValue))
            | (CGEventMask(1) << CGEventMask(CGEventType.keyUp.rawValue))

        func makeTap(_ location: CGEventTapLocation) -> CFMachPort? {
            CGEvent.tapCreate(
                tap: location,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: { _, type, event, refcon in
                    guard let refcon else { return Unmanaged.passUnretained(event) }
                    let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                    let flags = event.flags
                    let consumed = manager.shortcutFilter.shouldConsume(type: type, keyCode: keyCode, flags: flags)
                    Task { @MainActor in
                        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                            if let tap = manager.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                            return
                        }
                        manager.handleEvent(type: type, keyCode: keyCode, flags: flags)
                    }
                    return consumed ? nil : Unmanaged.passUnretained(event)
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
            Self.logger.warning("Global input event tap unavailable; accessibility=\(AXIsProcessTrusted()), inputMonitoring=\(CGPreflightListenEventAccess())")
            // Setup can grant access after launch. NSEvent's global monitor cannot
            // consume shortcuts, so replace the fallback as soon as access is ready.
            permissionRetryTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(2)) }
                    catch { return }
                    guard self != nil else { return }
                    self?.retryEventTapIfAuthorized()
                }
            }
        }
    }

    private func retryEventTapIfAuthorized() {
        guard !isUsingEventTap, let handler,
              AXIsProcessTrusted(), CGPreflightListenEventAccess() else { return }
        startListening(handler: handler)
    }

    func stopListening() {
        permissionRetryTask?.cancel()
        permissionRetryTask = nil
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
        shortcutFilter.reset()
    }

    private func handleEvent(type: CGEventType, keyCode: CGKeyCode, flags: CGEventFlags) {
        guard type == .flagsChanged || type == .keyDown || type == .keyUp else { return }
        handler?(type, keyCode, flags)
    }

    private func installNSEventFallback() {
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .keyUp]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            _ = self?.shortcutFilter.shouldConsume(
                type: Self.cgType(from: event.type),
                keyCode: CGKeyCode(event.keyCode),
                flags: Self.cgFlags(from: event.modifierFlags)
            )
            Task { @MainActor in self?.handle(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            let type = Self.cgType(from: event.type)
            let consumed = self?.shortcutFilter.shouldConsume(
                type: type,
                keyCode: CGKeyCode(event.keyCode),
                flags: Self.cgFlags(from: event.modifierFlags)
            ) ?? false
            Task { @MainActor in self?.handle(event) }
            return consumed ? nil : event
        }
    }

    private func handle(_ event: NSEvent) {
        let type = Self.cgType(from: event.type)
        handleEvent(
            type: type,
            keyCode: CGKeyCode(event.keyCode),
            flags: Self.cgFlags(from: event.modifierFlags)
        )
    }

    private nonisolated static func cgType(from type: NSEvent.EventType) -> CGEventType {
        switch type {
        case .flagsChanged: .flagsChanged
        case .keyUp: .keyUp
        default: .keyDown
        }
    }

    private nonisolated static func cgFlags(from flags: NSEvent.ModifierFlags) -> CGEventFlags {
        var result: CGEventFlags = []
        if flags.contains(.command) { result.insert(.maskCommand) }
        if flags.contains(.option) { result.insert(.maskAlternate) }
        if flags.contains(.control) { result.insert(.maskControl) }
        if flags.contains(.shift) { result.insert(.maskShift) }
        return result
    }
}
