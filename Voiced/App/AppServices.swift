import AppKit

@MainActor
enum AppServices {
    static let settings = SettingsStore()
    static let lastCapture = LastCaptureStore()
    static let settingsNavigation = SettingsNavigation()
    static let telemetry = TelemetryService()
}

@MainActor
final class VoicedAppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?
    private var statusMenu: StatusMenuController?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = AppServices.settings
        let lastCapture = AppServices.lastCapture
        let telemetry = AppServices.telemetry
        telemetry.configure(settings: settings)
        statusMenu = StatusMenuController(settings: settings, lastCapture: lastCapture)
        coordinator = AppCoordinator(settings: settings, lastCapture: lastCapture, telemetry: telemetry)
        coordinator?.start()
        Task { @MainActor [weak self] in
            self?.onboardingWindow = IntroOnboardingPresenter.presentIfNeeded(settings: settings) { [weak self] in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
            }
        }
    }
}
