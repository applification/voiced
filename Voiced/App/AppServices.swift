import AppKit

@MainActor
enum AppServices {
    static let settings = SettingsStore()
    static let settingsNavigation = SettingsNavigation()
    static let recentTranscripts = RecentTranscriptStore()
    static let telemetry = TelemetryService()
}

@MainActor
final class VoicedAppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?
    private var statusMenu: StatusMenuController?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = AppServices.settings
        let telemetry = AppServices.telemetry
        telemetry.configure(settings: settings)
        let recentTranscripts = AppServices.recentTranscripts
        statusMenu = StatusMenuController(settings: settings, recentTranscripts: recentTranscripts)
        coordinator = AppCoordinator(settings: settings, recentTranscripts: recentTranscripts, telemetry: telemetry)
        coordinator?.start()
        Task { @MainActor [weak self] in
            self?.onboardingWindow = IntroOnboardingPresenter.presentIfNeeded(settings: settings) { [weak self] in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
            }
        }
    }
}
