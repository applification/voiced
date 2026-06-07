import AppKit
import AVFoundation
import SwiftUI

@MainActor
extension StatusMenuController {
    @objc func setOutputPaste() {
        settings.outputMode = .clipboardPaste
    }

    @objc func setOutputCopy() {
        settings.outputMode = .copyOnly
    }

    @objc func setPushToTalkHotkey(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let hotkey = PushToTalkHotkey(rawValue: rawValue) else { return }
        settings.pushToTalkHotkey = hotkey
        rebuildMenu()
    }

    @objc func setActivationSound(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let cue = SoundCue(rawValue: rawValue) else { return }
        settings.activationSound = cue
        previewSound(cue)
        rebuildMenu()
    }

    @objc func setDeactivationSound(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let cue = SoundCue(rawValue: rawValue) else { return }
        settings.deactivationSound = cue
        previewSound(cue)
        rebuildMenu()
    }

    func previewSound(_ cue: SoundCue) {
        guard let soundName = cue.soundName else { return }
        NSSound(named: soundName)?.play()
    }

    @objc func approveModelDownloads() {
        settings.modelDownloadsApproved = true
        NotificationCenter.default.post(name: .voicedModelApprovalChanged, object: nil)
        rebuildMenu()
    }

    @objc func warmUpModel() {
        if !settings.modelDownloadsApproved {
            settings.modelDownloadsApproved = true
            NotificationCenter.default.post(name: .voicedModelApprovalChanged, object: nil)
            rebuildMenu()
        }
        NotificationCenter.default.post(name: .voicedModelDownloadRequested, object: settings.transcriptionModel)
    }

    @objc func copyLastTranscript() {
        guard let transcript = lastCapture.last else {
            logger.warning("Copy Last Transcript selected without stored transcript")
            return
        }
        logger.info("Copy Last Transcript selected; characters=\(transcript.count, privacy: .public)")
        output.copyToClipboard(transcript, restoringAfter: 5)
    }

    @objc func pasteLastTranscript() {
        guard let transcript = lastCapture.last else {
            logger.warning("Paste Last Transcript selected without stored transcript")
            return
        }

        permissions.refreshStatuses()
        logger.info("Paste Last Transcript selected; accessibilityEnabled=\(self.permissions.accessibilityEnabled, privacy: .public) characters=\(transcript.count, privacy: .public)")
        guard permissions.accessibilityEnabled else {
            output.copyToClipboard(transcript)
            let decision = permissions.explainPasteAccessibilityAndChoose()
            if decision == .useClipboardOnly {
                settings.outputMode = .copyOnly
            }
            rebuildMenu()
            return
        }

        output.pastePreservingClipboard(transcript, targetApplication: nil)
    }

    @objc func testPastePermission() {
        let testText = "Voiced paste test"
        permissions.refreshStatuses()
        logger.info("Test Paste Permission selected; accessibilityEnabled=\(self.permissions.accessibilityEnabled, privacy: .public)")

        guard permissions.accessibilityEnabled else {
            output.copyToClipboard(testText)
            _ = permissions.explainPasteAccessibilityAndChoose()
            return
        }

        output.pastePreservingClipboard(testText, targetApplication: nil)
    }

    @objc func handleMicrophone() {
        guard !micAuthorized else {
            rebuildMenu()
            return
        }

        AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
            Task { @MainActor in self?.rebuildMenu() }
        }
    }

    @objc func handleAccessibility() {
        guard !accessibilityEnabled else {
            rebuildMenu()
            return
        }

        _ = permissions.explainPasteAccessibilityAndChoose()
    }

    @objc func showGettingStarted() {
        if let onboardingWindow {
            onboardingWindow.makeKeyAndOrderFront(nil)
        } else {
            onboardingWindow = IntroOnboardingPresenter.present(settings: settings) { [weak self] in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
            }
        }
    }

    @objc func openSettings() {
        presentSettings(section: .general)
    }

    @objc func openModelSettings() {
        presentSettings(section: .models)
    }

    func presentSettings(section: SettingsSection) {
        settingsNavigation.selectedSection = section
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
        } else {
            let hostingController = NSHostingController(rootView: SettingsView(settings: settings, navigation: settingsNavigation))
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Voiced Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 560, height: 360))
            window.minSize = NSSize(width: 560, height: 360)
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    var outputBehavior: OutputBehavior {
        switch settings.outputMode {
        case .clipboardPaste: .clipboardPaste
        case .copyOnly: .copyOnly
        }
    }
}
