import AppKit
import AVFoundation
@preconcurrency import ApplicationServices
import ServiceManagement

@MainActor
extension StatusMenuController {
    func rebuildMenu() {
        menu.removeAllItems()
        settings.launchAtLogin = SMAppService.mainApp.status == .enabled

        menu.addItem(infoItem(label: "Push-to-talk",
                              value: settings.pushToTalkHotkey.menuTitle,
                              symbolName: "keyboard",
                              color: .controlAccentColor))
        menu.addItem(statusItem(title: micAuthorized ? "Mic OK" : "Mic Needed",
                                symbolName: micAuthorized ? "checkmark.circle.fill" : "mic.slash.fill",
                                color: micAuthorized ? .systemGreen : .systemOrange))
        menu.addItem(statusItem(title: accessibilityEnabled ? "Paste Permission OK" : "Enable Accessibility for Paste",
                                symbolName: accessibilityEnabled ? "checkmark.circle.fill" : "hand.raised.fill",
                                color: accessibilityEnabled ? .systemGreen : .systemOrange))
        menu.addItem(.separator())

        addTranscriptMenuItems()
        addOutputMenu()
        addModelMenu()
        addPermissionMenuItems()
        menu.addItem(.separator())
        addAppMenuItems()
    }

    var micAuthorized: Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: true
        case .denied, .restricted, .notDetermined: false
        @unknown default: false
        }
    }

    var accessibilityEnabled: Bool {
        AXIsProcessTrustedWithOptions(nil)
    }

    func statusItem(title: String, symbolName: String, color: NSColor? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.image = menuIcon(symbolName, color: color)
        item.isEnabled = false
        return item
    }

    func infoItem(label: String, value: String, symbolName: String, color: NSColor? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 4, left: 14, bottom: 4, right: 14)

        let imageView = NSImageView()
        imageView.image = menuIcon(symbolName, color: color ?? .secondaryLabelColor)
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        imageView.setContentHuggingPriority(.required, for: .horizontal)

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1

        let labelField = NSTextField(labelWithString: label)
        labelField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        labelField.textColor = .secondaryLabelColor
        labelField.lineBreakMode = .byTruncatingTail

        let valueField = NSTextField(labelWithString: value)
        valueField.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        valueField.textColor = .labelColor
        valueField.lineBreakMode = .byTruncatingTail

        textStack.addArrangedSubview(labelField)
        textStack.addArrangedSubview(valueField)
        row.addArrangedSubview(imageView)
        row.addArrangedSubview(textStack)
        row.frame = NSRect(x: 0, y: 0, width: 285, height: 42)
        item.view = row
        return item
    }

    func actionItem(title: String,
                    action: Selector,
                    keyEquivalent: String = "",
                    state: NSControl.StateValue = .off,
                    representedObject: Any? = nil,
                    symbolName: String? = nil,
                    color: NSColor? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.state = state
        item.representedObject = representedObject
        if let symbolName {
            item.image = menuIcon(symbolName, color: color)
        }
        return item
    }

    func menuIcon(_ symbolName: String, color: NSColor? = nil) -> NSImage? {
        guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
            return nil
        }

        if let color,
           let configured = image.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [color])) {
            configured.isTemplate = false
            return configured
        }

        image.isTemplate = true
        return image
    }

    private func addOutputMenu() {
        let outputMenu = NSMenu()
        outputMenu.addItem(actionItem(title: "Paste",
                                      action: #selector(setOutputPaste),
                                      state: settings.outputMode == .clipboardPaste ? .on : .off,
                                      symbolName: "text.insert",
                                      color: .secondaryLabelColor))
        outputMenu.addItem(actionItem(title: "Copy",
                                      action: #selector(setOutputCopy),
                                      state: settings.outputMode == .copyOnly ? .on : .off,
                                      symbolName: "doc.on.clipboard",
                                      color: .secondaryLabelColor))
        let outputItem = NSMenuItem(title: "Output", action: nil, keyEquivalent: "")
        outputItem.image = menuIcon("arrowshape.turn.up.right.fill", color: .secondaryLabelColor)
        outputItem.submenu = outputMenu
        menu.addItem(outputItem)
    }

    private func addPushToTalkMenu() {
        let hotkeyMenu = NSMenu()
        for hotkey in PushToTalkHotkey.allCases {
            hotkeyMenu.addItem(actionItem(title: hotkey.label,
                                          action: #selector(setPushToTalkHotkey(_:)),
                                          state: settings.pushToTalkHotkey == hotkey ? .on : .off,
                                          representedObject: hotkey.rawValue))
        }

        let hotkeyItem = NSMenuItem(title: "Push-to-Talk Key", action: nil, keyEquivalent: "")
        hotkeyItem.submenu = hotkeyMenu
        menu.addItem(hotkeyItem)
    }

    private func addModelMenu() {
        let modelStore = ModelStore(model: settings.transcriptionModel)
        let modelMenu = NSMenu()
        modelMenu.addItem(infoItem(label: "Selected model",
                                   value: settings.transcriptionModel.menuTitle,
                                   symbolName: "brain",
                                   color: .controlAccentColor))
        modelMenu.addItem(infoItem(label: "Download size",
                                   value: modelStore.formattedSize,
                                   symbolName: modelStore.isDownloaded ? "internaldrive" : "icloud.and.arrow.down"))
        if settings.modelDownloadsApproved {
            modelMenu.addItem(infoItem(label: "Downloads",
                                       value: "Approved",
                                       symbolName: "checkmark.seal.fill",
                                       color: .systemGreen))
        } else {
            modelMenu.addItem(actionItem(title: "Approve Downloads",
                                         action: #selector(approveModelDownloads),
                                         symbolName: "arrow.down.circle.fill",
                                         color: .systemOrange))
        }

        modelMenu.addItem(.separator())
        modelMenu.addItem(actionItem(title: "Model Settings...",
                                     action: #selector(openModelSettings),
                                     symbolName: "gearshape",
                                     color: .secondaryLabelColor))

        let warmUpItem = actionItem(title: "Warm Up Model", action: #selector(warmUpModel))
        warmUpItem.isEnabled = settings.modelDownloadsApproved
        modelMenu.addItem(warmUpItem)

        let modelItem = NSMenuItem(title: "Model", action: nil, keyEquivalent: "")
        modelItem.image = menuIcon("brain.head.profile", color: .secondaryLabelColor)
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

    private func addTranscriptMenuItems() {
        let hasLastCapture = lastCapture.last != nil
        let copyLast = actionItem(title: "Copy Last Transcript",
                                  action: #selector(copyLastTranscript),
                                  symbolName: "doc.on.clipboard",
                                  color: .controlAccentColor)
        copyLast.isEnabled = hasLastCapture
        menu.addItem(copyLast)

        let pasteLast = actionItem(title: "Paste Last Transcript",
                                   action: #selector(pasteLastTranscript),
                                   symbolName: "text.insert",
                                   color: .controlAccentColor)
        pasteLast.isEnabled = hasLastCapture
        menu.addItem(pasteLast)

        let testPaste = actionItem(title: "Test Paste Permission",
                                   action: #selector(testPastePermission),
                                   symbolName: "checkmark.shield",
                                   color: .secondaryLabelColor)
        menu.addItem(testPaste)
    }

    private func addPermissionMenuItems() {
        guard !micAuthorized || !accessibilityEnabled else { return }

        menu.addItem(.separator())
        if !micAuthorized {
            menu.addItem(actionItem(title: "Allow Microphone...",
                                    action: #selector(handleMicrophone),
                                    symbolName: "mic.slash.fill",
                                    color: .systemOrange))
        }
        if !accessibilityEnabled {
            menu.addItem(actionItem(title: "Open Accessibility Settings...",
                                    action: #selector(handleAccessibility),
                                    symbolName: "hand.raised.fill",
                                    color: .systemOrange))
        }
    }

    private func addAppMenuItems() {
        menu.addItem(actionItem(title: "Getting Started...",
                                action: #selector(showGettingStarted),
                                symbolName: "questionmark.circle",
                                color: .secondaryLabelColor))
        menu.addItem(actionItem(title: "Settings...",
                                action: #selector(openSettings),
                                symbolName: "gearshape.fill",
                                color: .secondaryLabelColor))
        menu.addItem(actionItem(title: "Quit Voiced",
                                action: #selector(quit),
                                keyEquivalent: "q",
                                symbolName: "power",
                                color: .secondaryLabelColor))
    }
}
