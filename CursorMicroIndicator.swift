import AppKit
import SwiftUI

@MainActor
final class CursorMicroIndicator {
    private var panel: NSPanel?
    private var followTask: Task<Void, Never>?

    func showTranscribingAtCursor() {
        let panel = existingOrCreatePanel()
        panel.contentView = TransparentHostingView(rootView: CursorMicroIndicatorView())
        position(panel, near: NSEvent.mouseLocation)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        startFollowingCursor(panel)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        followTask?.cancel()
        followTask = nil
        guard let panel, panel.isVisible else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
                panel.contentView = nil
            }
        }
    }

    private func startFollowingCursor(_ panel: NSPanel) {
        followTask?.cancel()
        followTask = Task { @MainActor [weak self, weak panel] in
            while !Task.isCancelled {
                guard let self, let panel, panel.isVisible else { break }
                self.position(panel, near: NSEvent.mouseLocation)
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
    }

    private func existingOrCreatePanel() -> NSPanel {
        if let panel { return panel }

        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 30, height: 22),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel, near cursorLocation: NSPoint) {
        let size = NSSize(width: 30, height: 22)
        panel.setContentSize(size)

        let screen = NSScreen.screens.first { NSMouseInRect(cursorLocation, $0.frame, false) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let offset = NSPoint(x: 8, y: -12)
        let origin = NSPoint(
            x: min(max(cursorLocation.x + offset.x, visibleFrame.minX + 8), visibleFrame.maxX - size.width - 8),
            y: min(max(cursorLocation.y + offset.y, visibleFrame.minY + 8), visibleFrame.maxY - size.height - 8)
        )
        panel.setFrameOrigin(origin)
    }
}

private struct CursorMicroIndicatorView: View {
    private let accent = Color(red: 0.48, green: 0.78, blue: 0.56)

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<5) { index in
                CursorWaveBar(color: accent, delay: Double(index) * 0.08)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(.regularMaterial)
        }
        .overlay {
            Capsule()
                .strokeBorder(.primary.opacity(0.12))
        }
        .shadow(color: .black.opacity(0.14), radius: 6, y: 2)
        .fixedSize()
    }
}

private struct CursorWaveBar: View {
    let color: Color
    let delay: Double

    @State private var isActive = false

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(color)
            .frame(width: 3, height: isActive ? 11 : 5)
            .opacity(isActive ? 1 : 0.46)
            .animation(
                .easeInOut(duration: 0.46)
                    .delay(delay)
                    .repeatForever(autoreverses: true),
                value: isActive
            )
            .onAppear {
                isActive = true
            }
    }
}
