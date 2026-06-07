import AppKit
import AVFoundation
import Combine
@preconcurrency import ApplicationServices

enum AccessibilityPastePermissionDecision: Equatable {
    case openSettings
    case useClipboardOnly
}

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

    @MainActor
    func explainPasteAccessibilityAndChoose() -> AccessibilityPastePermissionDecision {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Allow Voiced to paste for you?"
        alert.informativeText = """
        Paste mode needs Accessibility permission so Voiced can send Command-V to the app you were typing in after transcription.

        Voiced does not read your keystrokes. If you prefer not to grant this permission, your transcript has been copied to the clipboard so you can paste it manually.
        """
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "Use Clipboard Only")
        alert.icon = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: "Accessibility permission")

        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilityPrefs()
            return .openSettings
        }

        return .useClipboardOnly
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
