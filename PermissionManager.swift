import AppKit
import AVFoundation
import Combine
@preconcurrency import ApplicationServices

final class PermissionManager: ObservableObject {
    @Published private(set) var micAuthorized: Bool = false
    @Published private(set) var accessibilityEnabled: Bool = false

    func refreshStatuses() {
        micAuthorized = AVAudioApplication.shared.isMicrophoneAccessGranted
        accessibilityEnabled = AXIsProcessTrustedWithOptions(nil)
    }

    func requestMicrophone(completion: @Sendable @escaping (Bool) -> Void) {
        AVAudioApplication.shared.requestMicrophoneAccess { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func openAccessibilityPrefs() {
        requestAccessibilityPrompt()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func requestAccessibilityPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

// Shim layer for macOS microphone permissions.
// AVAudioSession isn't available; use AVCaptureDevice authorization APIs.
struct AVAudioApplication: Sendable {
    static let shared = AVAudioApplication()

    var isMicrophoneAccessGranted: Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .denied, .restricted: return false
        case .notDetermined: return false
        @unknown default: return false
        }
    }

    func requestMicrophoneAccess(_ completion: @Sendable @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            completion(granted)
        }
    }
}
