import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
private final class CursorTranscriptPresentation {
    var state = LiveTranscriptState.idle
    var status = "Listening"
    var level: Double = 0
    var isComplete = false
    var onCancel: () -> Void = {}
    var onCopy: () -> Void = {}
    var onDismiss: () -> Void = {}
}

/// Restores the cursor transcript surface without taking focus from the destination.
@MainActor
final class CursorTranscriptPanel {
    private let model = CursorTranscriptPresentation()
    private var panel: NSPanel?

    func show(status: String, onCancel: @escaping () -> Void) {
        model.state = .idle
        model.status = status
        model.isComplete = false
        model.level = 0
        model.onCancel = onCancel
        model.onDismiss = { [weak self] in self?.hide() }
        let panel = panel ?? makePanel()
        self.panel = panel
        let anchor = AccessibilityTextTarget.caretPoint() ?? NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(anchor) } ?? NSScreen.main
        let bounds = (screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)).insetBy(dx: 12, dy: 12)
        let x = min(max(anchor.x, bounds.minX), bounds.maxX - panel.frame.width)
        let below = anchor.y - panel.frame.height - 12
        let y = below >= bounds.minY ? below : min(anchor.y + 24, bounds.maxY - panel.frame.height)
        panel.setFrameOrigin(NSPoint(x: x, y: max(bounds.minY, y)))
        panel.orderFrontRegardless()
    }

    func update(_ state: LiveTranscriptState) { model.state = state }
    func updateLevel(_ level: Double) { model.level = level }
    func setStatus(_ status: String) { model.status = status }

    func retain(text: String, status: String, onCopy: @escaping () -> Void) {
        model.state = LiveTranscriptState(committedText: text, provisionalText: "", isRecording: false)
        model.status = status
        model.isComplete = true
        model.onCopy = onCopy
    }

    func hide() { panel?.orderOut(nil) }

    private func makePanel() -> NSPanel {
        let panel = TranscriptPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 190),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: CursorTranscriptView(model: model))
        return panel
    }
}

private final class TranscriptPanelWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct CursorTranscriptView: View {
    var model: CursorTranscriptPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: model.isComplete ? "checkmark.circle" : "waveform")
                    .foregroundStyle(VoicedShelfStyle.signalMint)
                    .opacity(model.isComplete ? 1 : 0.5 + model.level * 0.5)
                Text(model.status).font(.caption.weight(.medium)).lineLimit(2)
                Spacer(minLength: 4)
                Button(action: model.isComplete ? model.onDismiss : model.onCancel) {
                    Image(systemName: "xmark").font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.isComplete ? "Dismiss transcript" : "Cancel dictation")
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if model.state.combinedText.isEmpty {
                            Text("Speak naturally…").foregroundStyle(.secondary)
                        } else {
                            Text("\(model.state.committedText)\(model.state.committedText.isEmpty || model.state.provisionalText.isEmpty ? "" : " ")\(Text(model.state.provisionalText).foregroundColor(.secondary))")
                        }
                        Color.clear.frame(height: 1).id("end")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 15))
                    .lineSpacing(3)
                }
                .onChange(of: model.state.combinedText) { proxy.scrollTo("end", anchor: .bottom) }
            }
            HStack {
                Text(model.isComplete ? "Available in your Inbox" : "Release to finish · Esc to cancel")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if model.isComplete {
                    Button("Copy", action: model.onCopy).controlSize(.small)
                }
            }
        }
        .padding(16)
        .frame(width: 360, height: 190)
        .voicedGlassSurface(cornerRadius: 18)
    }
}
