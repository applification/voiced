import AppKit
import AVFoundation

final class PermissionManager: ObservableObject {
    @Published private(set) var micAuthorized: Bool = false
    @Published private(set) var accessibilityEnabled: Bool = false

    func refreshStatuses() {
        micAuthorized = AVAudioApplication.shared.isMicrophoneAccessGranted
        accessibilityEnabled = AXIsProcessTrustedWithOptions(nil)
    }

    func requestMicrophone(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.shared.requestMicrophoneAccess { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func openAccessibilityPrefs() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// Shim layer for macOS microphone permissions.
// AVAudioSession isn't available; use AVAudioDevice authorization APIs via AVAudioApplication.
// AVAudioApplication is available in macOS 14+; provide a fallback if needed.
final class AVAudioApplication {
    static let shared = AVAudioApplication()

    var isMicrophoneAccessGranted: Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .denied, .restricted: return false
        case .notDetermined: return false
        @unknown default: return false
        }
    }

    func requestMicrophoneAccess(_ completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            completion(granted)
        }
    }
}
