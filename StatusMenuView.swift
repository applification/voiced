import AppKit
import SwiftUI
import AVFoundation
import ApplicationServices

struct StatusMenuView: View {
    var settings: SettingsStore
    @State private var micAuthorized: Bool = false
    @State private var accessibilityEnabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(micAuthorized ? "Mic OK" : "Mic Needed", systemImage: micAuthorized ? "checkmark.circle" : "mic.slash")
                Spacer()
                Label(accessibilityEnabled ? "Hotkey OK" : "Enable Accessibility", systemImage: accessibilityEnabled ? "checkmark.circle" : "hand.raised")
            }
            .font(.callout)

            Divider()

            Picker("Output", selection: Bindable(settings).outputMode) {
                ForEach(OutputMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            Button("Copy Last Transcript") {
                // wired later when LastCaptureStore is integrated
            }
            .disabled(true)

            Button("Test Output") {
                let text = "Voiced test output"
                if settings.outputMode == .clipboardPaste {
                    pastePreservingClipboard(text)
                } else {
                    copyToClipboard(text)
                }
            }

            Divider()

            Button(micAuthorized ? "Recheck Microphone" : "Allow Microphone…") {
                if micAuthorized {
                    refreshStatuses()
                } else {
                    requestMicrophone { _ in refreshStatuses() }
                }
            }

            Button(accessibilityEnabled ? "Recheck Accessibility" : "Open Accessibility Settings…") {
                if accessibilityEnabled {
                    refreshStatuses()
                } else {
                    openAccessibilityPrefs()
                }
            }

            Divider()

            SettingsLink()

            Button("Quit Voiced") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(.vertical, 6)
        .onAppear { refreshStatuses() }
    }

    // MARK: - Local permission helpers
    private func refreshStatuses() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: micAuthorized = true
        case .denied, .restricted, .notDetermined: micAuthorized = false
        @unknown default: micAuthorized = false
        }
        accessibilityEnabled = AXIsProcessTrustedWithOptions(nil)
    }

    private func requestMicrophone(_ completion: @Sendable @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    private func openAccessibilityPrefs() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Clipboard helpers
    private func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    private func pastePreservingClipboard(_ text: String) {
        let pb = NSPasteboard.general
        let previousItems = pb.pasteboardItems
        pb.clearContents()
        pb.setString(text, forType: .string)
        postCommandV()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pb.clearContents()
            if let items = previousItems, !items.isEmpty {
                pb.writeObjects(items.compactMap { $0 })
            }
        }
    }

    private func postCommandV() {
        let vKey: CGKeyCode = 9 // 'v'
        guard let src = CGEventSource(stateID: .hidSystemState) else { return }
        guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false) else { return }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

struct SettingsView: View {
    var settings: SettingsStore

    var body: some View {
        Form {
            Picker("Output mode", selection: Bindable(settings).outputMode) {
                ForEach(OutputMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            Stepper(
                "Clear last capture after \(settings.copyLastTranscriptClearsAfterMinutes) minutes",
                value: Bindable(settings).copyLastTranscriptClearsAfterMinutes,
                in: 10...30,
                step: 10
            )
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(width: 420)
    }
}
