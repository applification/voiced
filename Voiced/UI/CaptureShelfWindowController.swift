import AppKit
import SwiftUI

@MainActor
final class CaptureShelfWindowController: NSObject, NSWindowDelegate {
    private let store: CaptureStore
    private let permissions: SystemPermissionManager
    private let output: OutputManager
    private let contextTracker: ApplicationContextTracker
    private let transcriptProcessor: any TranscriptProcessing
    private let reminderExporter: any ReminderExporting
    private let selection = CaptureShelfSelection()
    private var window: NSWindow?
    private var toggleObserver: NSObjectProtocol?
    private var showObserver: NSObjectProtocol?

    init(
        store: CaptureStore,
        permissions: SystemPermissionManager,
        output: OutputManager,
        contextTracker: ApplicationContextTracker,
        transcriptProcessor: any TranscriptProcessing,
        reminderExporter: any ReminderExporting
    ) {
        self.store = store
        self.permissions = permissions
        self.output = output
        self.contextTracker = contextTracker
        self.transcriptProcessor = transcriptProcessor
        self.reminderExporter = reminderExporter
        super.init()

        toggleObserver = NotificationCenter.default.addObserver(
            forName: .voicedShelfToggleRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.toggle() }
        }
        showObserver = NotificationCenter.default.addObserver(
            forName: .voicedShelfShowRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let captureID = notification.object as? UUID
            Task { @MainActor in
                self?.show(selecting: captureID)
            }
        }
    }

    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show(selecting id: UUID? = nil) {
        _ = contextTracker.rememberFrontmostExternalApplication()
        permissions.refresh()
        if let id, let item = store.item(id: id) {
            selection.select(item)
        }
        let window = existingOrCreateWindow()
        if !window.frameAutosaveName.isEmpty, !window.setFrameUsingName(window.frameAutosaveName) {
            position(window)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
        if let destination = contextTracker.runningApplication(for: contextTracker.mostRecentDestination) {
            _ = destination.activate(options: [.activateAllWindows])
        }
    }

    private func existingOrCreateWindow() -> NSWindow {
        if let window { return window }

        let rootView = CaptureShelfView(
            store: store,
            permissions: permissions,
            selection: selection,
            processingAvailability: transcriptProcessor.availability,
            onAddTyped: { [weak self] text in
                guard let self else { return nil }
                return self.store.add(
                    text: text,
                    source: .typed,
                    sourceApplication: self.contextTracker.mostRecentDestination?.captureSource
                )
            },
            onCopy: { [weak self] text in
                _ = self?.output.copyToClipboard(text)
            },
            onProcess: { [weak self] profile, text in
                guard let self else { return text }
                return try await self.transcriptProcessor.process(text, profile: profile)
            },
            onLoadReminderLists: { [weak self] requestingAccess in
                guard let self else { return [] }
                return (try? await self.reminderExporter.reminderLists(requestingAccess: requestingAccess)) ?? []
            },
            onExportToReminders: { [weak self] checklist, listID in
                guard let self else { return .failure("Reminders export is unavailable") }
                do {
                    let count = try await self.reminderExporter.exportChecklist(from: checklist, to: listID)
                    return .success(count: count)
                } catch {
                    return .failure("Could not add reminders")
                }
            }
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Voiced Shelf"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .normal
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 840, height: 500)
        window.setContentSize(NSSize(width: 900, height: 590))
        window.setFrameAutosaveName("VoicedCaptureShelf")
        window.delegate = self
        self.window = window
        position(window)
        return window
    }

    private func position(_ window: NSWindow) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else { return }
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(
            x: visibleFrame.maxX - size.width - 18,
            y: visibleFrame.midY - size.height / 2
        ))
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }
}
