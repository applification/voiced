import AppKit
import AVFoundation
import ServiceManagement
import SwiftUI

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate, NSWindowDelegate {
    private let settings: SettingsStore
    private let settingsNavigation: SettingsNavigation
    private let captures: CaptureStore
    private let permissions: SystemPermissionManager

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    init(
        settings: SettingsStore,
        settingsNavigation: SettingsNavigation = AppServices.settingsNavigation,
        captures: CaptureStore,
        permissions: SystemPermissionManager
    ) {
        self.settings = settings
        self.settingsNavigation = settingsNavigation
        self.captures = captures
        self.permissions = permissions
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voiced")
        statusItem.button?.toolTip = "Voiced"
        statusItem.menu = menu
        menu.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(capturesChanged),
            name: .voicedCapturesChanged,
            object: captures
        )
        rebuildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        permissions.refresh()
        rebuildMenu()
    }

    @objc private func capturesChanged() {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        settings.launchAtLogin = SMAppService.mainApp.status == .enabled

        menu.addItem(actionItem(
            title: "Open Capture Shelf",
            action: #selector(openShelf),
            keyEquivalent: " ",
            keyModifiers: [.option],
            symbolName: "rectangle.rightthird.inset.filled"
        ))
        menu.addItem(.separator())
        menu.addItem(infoItem(title: "Right Command: dictate and insert", symbolName: "arrow.turn.down.left"))
        menu.addItem(infoItem(title: "Shift + Right Command: save voice capture", symbolName: "waveform"))
        menu.addItem(infoItem(title: "Double Shift to capture selection", symbolName: "selection.pin.in.out"))
        menu.addItem(.separator())

        addPermissionItems()
        menu.addItem(.separator())
        addRecentCaptures()
        menu.addItem(.separator())

        menu.addItem(actionItem(
            title: "Model Settings…",
            action: #selector(openModelSettings),
            symbolName: "brain.head.profile"
        ))
        menu.addItem(actionItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ",",
            keyModifiers: [.command],
            symbolName: "gearshape"
        ))
        menu.addItem(actionItem(
            title: "Setup Guide…",
            action: #selector(showSetupGuide),
            symbolName: "checklist"
        ))
        menu.addItem(actionItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            state: settings.launchAtLogin ? .on : .off,
            symbolName: "power"
        ))
        menu.addItem(.separator())
        menu.addItem(actionItem(
            title: "Quit Voiced",
            action: #selector(quit),
            keyEquivalent: "q",
            keyModifiers: [.command]
        ))
    }

    private func addPermissionItems() {
        menu.addItem(permissionItem(
            title: "Microphone",
            granted: permissions.microphoneAuthorized,
            action: #selector(handleMicrophone)
        ))
        menu.addItem(permissionItem(
            title: "Accessibility",
            granted: permissions.accessibilityAuthorized,
            action: #selector(openAccessibilitySettings)
        ))
        menu.addItem(permissionItem(
            title: "Input Monitoring",
            granted: permissions.inputMonitoringAuthorized,
            action: #selector(openInputMonitoringSettings)
        ))
    }

    private func addRecentCaptures() {
        let submenu = NSMenu()
        let recent = captures.items.prefix(6)
        if recent.isEmpty {
            let empty = NSMenuItem(title: "No captures yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        } else {
            for item in recent {
                let menuItem = NSMenuItem(
                    title: shortTitle(item.text),
                    action: #selector(openCapture(_:)),
                    keyEquivalent: ""
                )
                menuItem.target = self
                menuItem.representedObject = item.id
                menuItem.image = NSImage(systemSymbolName: item.source.symbolName, accessibilityDescription: nil)
                submenu.addItem(menuItem)
            }
        }
        let root = NSMenuItem(title: "Recent Captures", action: nil, keyEquivalent: "")
        root.submenu = submenu
        root.image = NSImage(systemSymbolName: "clock", accessibilityDescription: nil)
        menu.addItem(root)
    }

    private func permissionItem(title: String, granted: Bool, action: Selector) -> NSMenuItem {
        actionItem(
            title: granted ? "\(title) Ready" : "Enable \(title)…",
            action: action,
            symbolName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
            color: granted ? .systemGreen : .systemOrange
        )
    }

    private func infoItem(title: String, symbolName: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        item.isEnabled = false
        return item
    }

    private func actionItem(
        title: String,
        action: Selector,
        keyEquivalent: String = "",
        keyModifiers: NSEvent.ModifierFlags = [],
        state: NSControl.StateValue = .off,
        symbolName: String? = nil,
        color: NSColor? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.keyEquivalentModifierMask = keyModifiers
        item.state = state
        if let symbolName, let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            if let color,
               let configured = image.withSymbolConfiguration(.init(paletteColors: [color])) {
                configured.isTemplate = false
                item.image = configured
            } else {
                item.image = image
            }
        }
        return item
    }

    private func shortTitle(_ text: String) -> String {
        let oneLine = text.replacingOccurrences(of: "\n", with: " ")
        return oneLine.count > 42 ? String(oneLine.prefix(39)) + "…" : oneLine
    }

    @objc private func openShelf() {
        NotificationCenter.default.post(name: .voicedShelfShowRequested, object: nil)
    }

    @objc private func openCapture(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        NotificationCenter.default.post(name: .voicedShelfShowRequested, object: id)
    }

    @objc private func handleMicrophone() {
        Task { @MainActor [weak self] in
            _ = await self?.permissions.requestMicrophone()
            self?.rebuildMenu()
        }
    }

    @objc private func openAccessibilitySettings() {
        permissions.openAccessibilitySettings()
    }

    @objc private func openInputMonitoringSettings() {
        permissions.openInputMonitoringSettings()
    }

    @objc private func toggleLaunchAtLogin() {
        let shouldEnable = SMAppService.mainApp.status != .enabled
        do {
            if shouldEnable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            settings.launchAtLogin = shouldEnable
        } catch {
            NSSound.beep()
        }
        rebuildMenu()
    }

    @objc private func showSetupGuide() {
        settingsWindow?.close()
        settingsWindow = nil
        if let onboardingWindow {
            onboardingWindow.makeKeyAndOrderFront(nil)
        } else {
            let window = IntroOnboardingPresenter.presentSetupGuide(settings: settings) { [weak self] in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
            }
            window.delegate = self
            onboardingWindow = window
        }
    }

    @objc private func openSettings() {
        presentSettings(section: .general)
    }

    @objc private func openModelSettings() {
        presentSettings(section: .models)
    }

    private func presentSettings(section: SettingsSection) {
        onboardingWindow?.close()
        onboardingWindow = nil
        settingsNavigation.selectedSection = section
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
        } else {
            let hostingController = NSHostingController(
                rootView: SettingsView(settings: settings, navigation: settingsNavigation)
            )
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Voiced Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 560, height: 590))
            window.minSize = NSSize(width: 560, height: 590)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === settingsWindow { settingsWindow = nil }
        if window === onboardingWindow { onboardingWindow = nil }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
