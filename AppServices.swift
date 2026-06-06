import AppKit

@MainActor
enum AppServices {
    static let settings = SettingsStore()
    static let lastCapture = LastCaptureStore()
    static let settingsNavigation = SettingsNavigation()
}

@MainActor
final class VoicedAppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?
    private var statusMenu: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = AppServices.settings
        let lastCapture = AppServices.lastCapture
        statusMenu = StatusMenuController(settings: settings, lastCapture: lastCapture)
        coordinator = AppCoordinator(settings: settings, lastCapture: lastCapture)
        coordinator?.start()
    }
}
