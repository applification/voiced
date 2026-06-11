import AppKit
import AVFoundation
import ServiceManagement
import SwiftUI

@MainActor
extension StatusMenuController {
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

    @objc func openRecentTranscript(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        NotificationCenter.default.post(name: .voicedRecentTranscriptSelected, object: id)
    }

    @objc func clearRecentTranscripts() {
        recentTranscripts.clear()
        rebuildMenu()
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

    @objc func toggleLaunchAtLogin() {
        let shouldEnable = SMAppService.mainApp.status != .enabled
        do {
            if shouldEnable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            settings.launchAtLogin = shouldEnable
            rebuildMenu()
        } catch {
            NSSound.beep()
        }
    }

    @objc func showSetupGuide() {
        closeSettingsWindow()

        if let onboardingWindow {
            onboardingWindow.makeKeyAndOrderFront(nil)
        } else {
            let window = IntroOnboardingPresenter.presentSetupGuide(settings: settings) { [weak self] in
                self?.closeOnboardingWindow()
            }
            window.delegate = self
            onboardingWindow = window
        }
    }

    @objc func openSettings() {
        guard settings.hasSeenIntroOnboarding else {
            rebuildMenu()
            return
        }
        presentSettings(section: .general)
    }

    @objc func openModelSettings() {
        presentSettings(section: .models)
    }

    func presentSettings(section: SettingsSection) {
        closeOnboardingWindow()

        settingsNavigation.selectedSection = section
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
        } else {
            let hostingController = NSHostingController(rootView: SettingsView(settings: settings, navigation: settingsNavigation))
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Voiced Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 560, height: 590))
            window.minSize = NSSize(width: 560, height: 590)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeSettingsWindow() {
        settingsWindow?.close()
        settingsWindow = nil
    }

    private func closeOnboardingWindow() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === settingsWindow {
            settingsWindow = nil
        } else if window === onboardingWindow {
            onboardingWindow = nil
        }
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}
