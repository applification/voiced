import AppKit
import AVFoundation
import ApplicationServices
import os
import ServiceManagement
import SwiftUI

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let settings: SettingsStore
    private let lastCapture: LastCaptureStore
    private let output = OutputManager()
    private let permissions = PermissionManager()
    private let logger = Logger(subsystem: "net.applification.voiced", category: "status-menu")

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var settingsWindow: NSWindow?

    init(settings: SettingsStore, lastCapture: LastCaptureStore) {
        self.settings = settings
        self.lastCapture = lastCapture
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voiced")
        statusItem.button?.toolTip = "Voiced"
        statusItem.menu = menu
        menu.delegate = self
        rebuildMenu()

        logger.info("Installed AppKit status item")
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        settings.launchAtLogin = SMAppService.mainApp.status == .enabled

        menu.addItem(statusItem(title: micAuthorized ? "Mic OK" : "Mic Needed",
                                symbolName: micAuthorized ? "checkmark.circle" : "mic.slash"))
        menu.addItem(statusItem(title: accessibilityEnabled ? "Paste Permission OK" : "Enable Accessibility for Paste",
                                symbolName: accessibilityEnabled ? "checkmark.circle" : "hand.raised"))
        menu.addItem(.separator())

        let outputMenu = NSMenu()
        outputMenu.addItem(actionItem(title: "Paste",
                                      action: #selector(setOutputPaste),
                                      state: settings.outputMode == .clipboardPaste ? .on : .off))
        outputMenu.addItem(actionItem(title: "Copy",
                                      action: #selector(setOutputCopy),
                                      state: settings.outputMode == .copyOnly ? .on : .off))
        let outputItem = NSMenuItem(title: "Output", action: nil, keyEquivalent: "")
        outputItem.submenu = outputMenu
        menu.addItem(outputItem)
        menu.addItem(actionItem(title: settings.modelDownloadsApproved ? "Model Downloads Approved" : "Approve Model Downloads",
                                action: #selector(approveModelDownloads),
                                state: settings.modelDownloadsApproved ? .on : .off))
        addModelMenu()
        addSoundMenu()
        menu.addItem(.separator())

        let hasLastCapture = lastCapture.last != nil
        let copyLast = actionItem(title: "Copy Last Transcript", action: #selector(copyLastTranscript))
        copyLast.isEnabled = hasLastCapture
        menu.addItem(copyLast)
        let clearLast = actionItem(title: "Clear Last Transcript", action: #selector(clearLastTranscript))
        clearLast.isEnabled = hasLastCapture
        menu.addItem(clearLast)
        menu.addItem(actionItem(title: "Test Output", action: #selector(testOutput)))
        menu.addItem(.separator())

        menu.addItem(actionItem(title: micAuthorized ? "Recheck Microphone" : "Allow Microphone...",
                                action: #selector(handleMicrophone)))
        menu.addItem(actionItem(title: accessibilityEnabled ? "Recheck Accessibility" : "Open Accessibility Settings...",
                                action: #selector(handleAccessibility)))
        menu.addItem(.separator())

        menu.addItem(actionItem(title: "Launch at Login",
                                action: #selector(toggleLaunchAtLogin),
                                state: settings.launchAtLogin ? .on : .off))
        menu.addItem(actionItem(title: "Settings...", action: #selector(openSettings)))
        menu.addItem(actionItem(title: "Quit Voiced", action: #selector(quit), keyEquivalent: "q"))
    }

    private var micAuthorized: Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: true
        case .denied, .restricted, .notDetermined: false
        @unknown default: false
        }
    }

    private var accessibilityEnabled: Bool {
        AXIsProcessTrustedWithOptions(nil)
    }

    private func statusItem(title: String, symbolName: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        item.isEnabled = false
        return item
    }

    private func actionItem(title: String,
                            action: Selector,
                            keyEquivalent: String = "",
                            state: NSControl.StateValue = .off,
                            representedObject: Any? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.state = state
        item.representedObject = representedObject
        return item
    }

    private func addModelMenu() {
        let modelStore = ModelStore(model: settings.transcriptionModel)
        let modelMenu = NSMenu()
        modelMenu.addItem(statusItem(title: "Model: \(settings.transcriptionModel.menuTitle)", symbolName: "brain"))
        modelMenu.addItem(statusItem(title: "Size: \(modelStore.formattedSize)", symbolName: modelStore.isDownloaded ? "internaldrive" : "icloud.and.arrow.down"))

        let choiceMenu = NSMenu()
        for model in TranscriptionModel.allCases {
            choiceMenu.addItem(actionItem(title: model.menuTitle,
                                          action: #selector(setTranscriptionModel(_:)),
                                          state: settings.transcriptionModel == model ? .on : .off,
                                          representedObject: model.rawValue))
        }
        let choiceItem = NSMenuItem(title: "Model Choice", action: nil, keyEquivalent: "")
        choiceItem.submenu = choiceMenu
        modelMenu.addItem(choiceItem)

        let pathItem = actionItem(title: "Show Model Folder", action: #selector(showModelFolder))
        pathItem.isEnabled = modelStore.isDownloaded
        modelMenu.addItem(pathItem)

        let warmUpItem = actionItem(title: "Warm Up Model", action: #selector(warmUpModel))
        warmUpItem.isEnabled = settings.modelDownloadsApproved
        modelMenu.addItem(warmUpItem)

        let deleteItem = actionItem(title: "Delete Downloaded Model", action: #selector(deleteDownloadedModel))
        deleteItem.isEnabled = modelStore.existsOnDisk
        modelMenu.addItem(deleteItem)

        let modelItem = NSMenuItem(title: "Model", action: nil, keyEquivalent: "")
        modelItem.submenu = modelMenu
        menu.addItem(modelItem)
    }

    private func addSoundMenu() {
        let soundMenu = NSMenu()

        let activationMenu = NSMenu()
        for cue in SoundCue.allCases {
            activationMenu.addItem(actionItem(title: cue.label,
                                              action: #selector(setActivationSound(_:)),
                                              state: settings.activationSound == cue ? .on : .off,
                                              representedObject: cue.rawValue))
        }
        let activationItem = NSMenuItem(title: "Activation", action: nil, keyEquivalent: "")
        activationItem.submenu = activationMenu
        soundMenu.addItem(activationItem)

        let deactivationMenu = NSMenu()
        for cue in SoundCue.allCases {
            deactivationMenu.addItem(actionItem(title: cue.label,
                                                action: #selector(setDeactivationSound(_:)),
                                                state: settings.deactivationSound == cue ? .on : .off,
                                                representedObject: cue.rawValue))
        }
        let deactivationItem = NSMenuItem(title: "Deactivation", action: nil, keyEquivalent: "")
        deactivationItem.submenu = deactivationMenu
        soundMenu.addItem(deactivationItem)

        let soundItem = NSMenuItem(title: "Sound Cues", action: nil, keyEquivalent: "")
        soundItem.submenu = soundMenu
        menu.addItem(soundItem)
    }

    @objc private func setOutputPaste() {
        settings.outputMode = .clipboardPaste
    }

    @objc private func setOutputCopy() {
        settings.outputMode = .copyOnly
    }

    @objc private func setActivationSound(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let cue = SoundCue(rawValue: rawValue) else { return }
        settings.activationSound = cue
        previewSound(cue)
        rebuildMenu()
    }

    @objc private func setDeactivationSound(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let cue = SoundCue(rawValue: rawValue) else { return }
        settings.deactivationSound = cue
        previewSound(cue)
        rebuildMenu()
    }

    private func previewSound(_ cue: SoundCue) {
        guard let soundName = cue.soundName else { return }
        NSSound(named: soundName)?.play()
    }

    @objc private func setTranscriptionModel(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let model = TranscriptionModel(rawValue: rawValue) else { return }
        settings.transcriptionModel = model
        NotificationCenter.default.post(name: .voicedModelApprovalChanged, object: nil)
        rebuildMenu()
    }

    @objc private func approveModelDownloads() {
        settings.modelDownloadsApproved = true
        NotificationCenter.default.post(name: .voicedModelApprovalChanged, object: nil)
        rebuildMenu()
    }

    @objc private func warmUpModel() {
        NotificationCenter.default.post(name: .voicedModelApprovalChanged, object: nil)
    }

    @objc private func showModelFolder() {
        let modelStore = ModelStore(model: settings.transcriptionModel)
        guard modelStore.isDownloaded else { return }
        NSWorkspace.shared.activateFileViewerSelecting([modelStore.localModelURL])
    }

    @objc private func deleteDownloadedModel() {
        let alert = NSAlert()
        alert.messageText = "Delete downloaded Whisper model?"
        alert.informativeText = "Voiced will ask for approval before downloading the model again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try ModelStore(model: settings.transcriptionModel).deleteDownloadedModel()
        } catch {
            logger.error("Failed to delete downloaded model: \(String(describing: error), privacy: .public)")
        }
        rebuildMenu()
    }

    @objc private func testOutput() {
        output.performOutput("Voiced test output", behavior: outputBehavior)
    }

    @objc private func copyLastTranscript() {
        guard let transcript = lastCapture.last else { return }
        output.copyToClipboard(transcript)
    }

    @objc private func clearLastTranscript() {
        lastCapture.clear()
        rebuildMenu()
    }

    @objc private func handleMicrophone() {
        guard !micAuthorized else {
            rebuildMenu()
            return
        }

        AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
            Task { @MainActor in self?.rebuildMenu() }
        }
    }

    @objc private func handleAccessibility() {
        guard !accessibilityEnabled else {
            rebuildMenu()
            return
        }

        permissions.openAccessibilityPrefs()
    }

    @objc private func toggleLaunchAtLogin() {
        let enabled = !settings.launchAtLogin
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            settings.launchAtLogin = enabled
        } catch {
            logger.error("Failed to update launch at login: \(String(describing: error), privacy: .public)")
        }
        rebuildMenu()
    }

    @objc private func openSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
        } else {
            let hostingController = NSHostingController(rootView: SettingsView(settings: settings))
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Voiced Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 520, height: 280))
            window.minSize = NSSize(width: 520, height: 280)
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private var outputBehavior: OutputBehavior {
        switch settings.outputMode {
        case .clipboardPaste: .clipboardPaste
        case .copyOnly: .copyOnly
        }
    }
}
