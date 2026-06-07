import AppKit
import os

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    let settings: SettingsStore
    let lastCapture: LastCaptureStore
    let settingsNavigation: SettingsNavigation
    let output = OutputManager()
    let permissions = PermissionManager()
    let logger = Logger(subsystem: "net.applification.voiced", category: "status-menu")

    let statusItem: NSStatusItem
    let menu = NSMenu()
    var settingsWindow: NSWindow?
    var onboardingWindow: NSWindow?

    init(settings: SettingsStore, lastCapture: LastCaptureStore, settingsNavigation: SettingsNavigation = AppServices.settingsNavigation) {
        self.settings = settings
        self.lastCapture = lastCapture
        self.settingsNavigation = settingsNavigation
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voiced")
        statusItem.button?.toolTip = "Voiced"
        statusItem.menu = menu
        menu.delegate = self
        rebuildMenu()

        logger.info("Installed AppKit status item")
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }
}
