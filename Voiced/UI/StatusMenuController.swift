import AppKit

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate, NSWindowDelegate {
    let settings: SettingsStore
    let settingsNavigation: SettingsNavigation
    let output = OutputManager()
    let permissions = MicrophonePermissionManager()

    let statusItem: NSStatusItem
    let menu = NSMenu()
    var settingsWindow: NSWindow?
    var onboardingWindow: NSWindow?

    init(settings: SettingsStore, settingsNavigation: SettingsNavigation = AppServices.settingsNavigation) {
        self.settings = settings
        self.settingsNavigation = settingsNavigation
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voiced")
        statusItem.button?.toolTip = "Voiced"
        statusItem.menu = menu
        menu.delegate = self
        rebuildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }
}
