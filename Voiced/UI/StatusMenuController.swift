import AppKit

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate, NSWindowDelegate {
    let settings: SettingsStore
    let settingsNavigation: SettingsNavigation
    let recentTranscripts: RecentTranscriptStore
    let output = OutputManager()
    let permissions = MicrophonePermissionManager()

    let statusItem: NSStatusItem
    let menu = NSMenu()
    var settingsWindow: NSWindow?
    var onboardingWindow: NSWindow?

    init(
        settings: SettingsStore,
        settingsNavigation: SettingsNavigation = AppServices.settingsNavigation,
        recentTranscripts: RecentTranscriptStore = AppServices.recentTranscripts
    ) {
        self.settings = settings
        self.settingsNavigation = settingsNavigation
        self.recentTranscripts = recentTranscripts
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voiced")
        statusItem.button?.toolTip = "Voiced"
        statusItem.menu = menu
        menu.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(recentTranscriptsChanged),
            name: .voicedRecentTranscriptsChanged,
            object: recentTranscripts
        )
        rebuildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        recentTranscripts.removeExpired()
        rebuildMenu()
    }

    @objc private func recentTranscriptsChanged() {
        rebuildMenu()
    }
}
