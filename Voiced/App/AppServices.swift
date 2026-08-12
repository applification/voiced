import AppKit

@MainActor
enum AppServices {
    static let settings = SettingsStore()
    static let settingsNavigation = SettingsNavigation()
    static let captures = CaptureStore()
    static let permissions = SystemPermissionManager()
    static let contextTracker = ApplicationContextTracker()
    static let output = OutputManager()
    static let transcriptProcessor = TranscriptProcessingService()
    static let reminderExporter = ReminderExportService()
}

@MainActor
final class VoicedAppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?
    private var statusMenu: StatusMenuController?
    private var shelf: CaptureShelfWindowController?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = AppServices.settings
        let captures = AppServices.captures
        let permissions = AppServices.permissions
        let contextTracker = AppServices.contextTracker
        shelf = CaptureShelfWindowController(
            store: captures,
            permissions: permissions,
            output: AppServices.output,
            contextTracker: contextTracker,
            transcriptProcessor: AppServices.transcriptProcessor,
            reminderExporter: AppServices.reminderExporter
        )
        statusMenu = StatusMenuController(
            settings: settings,
            captures: captures,
            permissions: permissions
        )
        coordinator = AppCoordinator(
            settings: settings,
            captures: captures,
            contextTracker: contextTracker,
            output: AppServices.output
        )
        coordinator?.start()
        Task { @MainActor [weak self] in
            self?.onboardingWindow = IntroOnboardingPresenter.presentIfNeeded(settings: settings) { [weak self] in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
            }
        }
        if ProcessInfo.processInfo.environment["VOICED_UI_SMOKE_SHELF"] == "1" {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                self?.shelf?.show()
            }
        }
    }
}
