import AVFoundation
import Combine

final class MicrophonePermissionManager: ObservableObject {
    @Published private(set) var micAuthorized: Bool = false

    func refreshStatuses() {
        micAuthorized = AVAudioApplication.shared.isMicrophoneAccessGranted
    }

    func requestMicrophone(completion: @Sendable @escaping (Bool) -> Void) {
        AVAudioApplication.shared.requestMicrophoneAccess { granted in
            DispatchQueue.main.async { completion(granted) }
        }
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
