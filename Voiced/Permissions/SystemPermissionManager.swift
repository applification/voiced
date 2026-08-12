import AppKit
import AVFoundation
@preconcurrency import ApplicationServices
import Observation

@MainActor
@Observable
final class SystemPermissionManager {
    private(set) var microphoneAuthorized = false
    private(set) var accessibilityAuthorized = false
    private(set) var inputMonitoringAuthorized = false

    init() {
        refresh()
    }

    func refresh() {
        microphoneAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        accessibilityAuthorized = AXIsProcessTrusted()
        inputMonitoringAuthorized = CGPreflightListenEventAccess()
    }

    func requestMicrophone() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        refresh()
        return granted
    }

    func requestAccessibility() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        refresh()
    }

    func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        refresh()
    }

    func openAccessibilitySettings() {
        requestAccessibility()
        openPrivacyPane("Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        requestInputMonitoring()
        openPrivacyPane("Privacy_ListenEvent")
    }

    private func openPrivacyPane(_ anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }
}
