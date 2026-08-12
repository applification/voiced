import AppKit

struct DestinationApplicationContext: Equatable {
    var processIdentifier: pid_t
    var name: String?
    var bundleIdentifier: String?

    var captureSource: CaptureSourceApplication {
        CaptureSourceApplication(name: name, bundleIdentifier: bundleIdentifier, url: nil)
    }
}

@MainActor
final class ApplicationContextTracker {
    private(set) var mostRecentDestination: DestinationApplicationContext?

    @discardableResult
    func rememberFrontmostExternalApplication() -> DestinationApplicationContext? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return mostRecentDestination
        }
        let context = DestinationApplicationContext(
            processIdentifier: application.processIdentifier,
            name: application.localizedName,
            bundleIdentifier: application.bundleIdentifier
        )
        mostRecentDestination = context
        return context
    }

    func remember(_ context: DestinationApplicationContext) {
        mostRecentDestination = context
    }

    func runningApplication(for context: DestinationApplicationContext?) -> NSRunningApplication? {
        guard let context else { return nil }
        if let application = NSRunningApplication(processIdentifier: context.processIdentifier),
           !application.isTerminated {
            return application
        }
        guard let bundleIdentifier = context.bundleIdentifier else { return nil }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
    }
}
