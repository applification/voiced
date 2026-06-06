import SwiftUI

@main
struct VoicedApp: App {
    @NSApplicationDelegateAdaptor(VoicedAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(settings: AppServices.settings, navigation: AppServices.settingsNavigation)
        }
    }
}
