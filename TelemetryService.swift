import Foundation
import os
#if canImport(PostHog)
import PostHog
#endif

enum TelemetryEvent: String {
    case appOpened = "app_opened"
    case recordingStarted = "recording_started"
    case recordingCancelled = "recording_cancelled"
    case transcriptionSucceeded = "transcription_succeeded"
    case transcriptionFailed = "transcription_failed"
    case modelLoadStarted = "model_load_started"
    case modelLoadSucceeded = "model_load_succeeded"
    case modelLoadFailed = "model_load_failed"
    case outputFailed = "output_failed"
    case permissionPromptShown = "permission_prompt_shown"
    case diagnosticError = "diagnostic_error"
}

enum TelemetryErrorCategory: String {
    case microphonePermission = "microphone_permission"
    case recordingStartFailed = "recording_start_failed"
    case modelLoadFailed = "model_load_failed"
    case transcriptionFailed = "transcription_failed"
    case pastePermissionNeeded = "paste_permission_needed"
    case outputFailed = "output_failed"
}

@MainActor
final class TelemetryService {
    private static let logger = Logger(subsystem: "net.applification.voiced", category: "telemetry")

    private var isConfigured = false
    private var isEnabled = false

    func configure(settings: SettingsStore) {
        isEnabled = settings.basicDiagnosticsEnabled

        #if canImport(PostHog)
        let projectToken = Self.bundleString(forKey: "PostHogProjectToken")
        guard !projectToken.isEmpty else {
            Self.logger.info("PostHog project token missing; telemetry disabled")
            return
        }

        let config = PostHogConfig(
            projectToken: projectToken,
            host: Self.bundleString(forKey: "PostHogHost", defaultValue: "https://eu.i.posthog.com")
        )
        config.optOut = !isEnabled
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.enableSwizzling = false
        config.personProfiles = .never
        config.preloadFeatureFlags = false
        config.sendFeatureFlagEvent = false
        config.errorTrackingConfig.autoCapture = true
        config.setBeforeSend { event in
            Self.redact(event)
        }

        PostHogSDK.shared.setup(config)
        isConfigured = true

        capture(.appOpened, properties: commonProperties())
        #else
        Self.logger.info("PostHog SDK unavailable; telemetry disabled")
        #endif
    }

    func setBasicDiagnosticsEnabled(_ enabled: Bool) {
        isEnabled = enabled

        #if canImport(PostHog)
        guard isConfigured else { return }
        if enabled {
            PostHogSDK.shared.optIn()
            capture(.appOpened, properties: commonProperties().merging(["reason": "diagnostics_enabled"]) { current, _ in current })
        } else {
            PostHogSDK.shared.optOut()
        }
        #endif
    }

    func capture(_ event: TelemetryEvent, properties: [String: Any] = [:]) {
        guard isEnabled else { return }

        #if canImport(PostHog)
        guard isConfigured else { return }
        PostHogSDK.shared.capture(event.rawValue, properties: commonProperties().merging(properties) { _, new in new })
        #endif
    }

    func captureError(_ category: TelemetryErrorCategory, properties: [String: Any] = [:]) {
        var eventProperties = properties
        eventProperties["category"] = category.rawValue
        capture(Self.event(for: category), properties: eventProperties)
    }

    private static func event(for category: TelemetryErrorCategory) -> TelemetryEvent {
        switch category {
        case .modelLoadFailed:
            return .modelLoadFailed
        case .transcriptionFailed:
            return .transcriptionFailed
        case .outputFailed:
            return .outputFailed
        case .microphonePermission, .recordingStartFailed, .pastePermissionNeeded:
            return .diagnosticError
        }
    }

    private func commonProperties() -> [String: Any] {
        var properties: [String: Any] = [
            "app_version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            "app_build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "macos_version": ProcessInfo.processInfo.operatingSystemVersionString,
            "processor_count": ProcessInfo.processInfo.processorCount
        ]

        #if arch(arm64)
        properties["architecture"] = "arm64"
        #elseif arch(x86_64)
        properties["architecture"] = "x86_64"
        #else
        properties["architecture"] = "unknown"
        #endif

        return properties
    }

    private static func bundleString(forKey key: String, defaultValue: String = "") -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return defaultValue
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.hasPrefix("$(") ? defaultValue : trimmed
    }

    #if canImport(PostHog)
    private static func redact(_ event: PostHogEvent) -> PostHogEvent? {
        let blockedEvents: Set<String> = ["$screen", "$snapshot"]
        guard !blockedEvents.contains(event.event) else { return nil }

        let blockedKeys: Set<String> = [
            "audio",
            "audio_path",
            "clipboard",
            "file",
            "file_path",
            "path",
            "target_application",
            "text",
            "transcript",
            "transcription"
        ]

        event.properties = event.properties.filter { key, _ in
            !blockedKeys.contains(key.lowercased())
        }
        return event
    }
    #endif
}
