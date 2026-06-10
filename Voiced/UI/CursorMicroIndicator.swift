import AppKit
import SwiftUI

@MainActor
final class CursorMicroIndicator: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var followTask: Task<Void, Never>?
    private var reviewAutoHideTask: Task<Void, Never>?
    private var resignActiveObserver: NSObjectProtocol?
    private var isShowingReview = false

    func showTranscribingAtCursor() {
        let panel = existingOrCreatePanel()
        isShowingReview = false
        panel.ignoresMouseEvents = true
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

    func showReviewAtCursor(text: String, onCopy: @escaping (String) -> Void) {
        followTask?.cancel()
        followTask = nil
        reviewAutoHideTask?.cancel()

        let panel = existingOrCreatePanel()
        isShowingReview = true
        panel.ignoresMouseEvents = false
        panel.contentView = TransparentHostingView(
            rootView: CursorTranscriptReviewView(
                text: text,
                onCopy: onCopy,
                onMoveWindow: { [weak panel] event in
                    panel?.performDrag(with: event)
                },
                onDismiss: { [weak self] in
                    self?.hide()
                }
            )
        )
        positionReview(panel, near: NSEvent.mouseLocation)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        installFocusDismissal()
        scheduleReviewAutoHide()
    }

    func hide() {
        isShowingReview = false
        removeFocusDismissal()
        reviewAutoHideTask?.cancel()
        reviewAutoHideTask = nil
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

    func hideImmediately() {
        isShowingReview = false
        removeFocusDismissal()
        reviewAutoHideTask?.cancel()
        reviewAutoHideTask = nil
        followTask?.cancel()
        followTask = nil
        guard let panel else { return }
        panel.alphaValue = 0
        panel.orderOut(nil)
        panel.contentView = nil
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
        panel.delegate = self
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.panel = panel
        return panel
    }

    nonisolated func windowDidResignKey(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard self?.isShowingReview == true else { return }
            self?.hide()
        }
    }

    private func installFocusDismissal() {
        removeFocusDismissal()
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard self?.isShowingReview == true else { return }
                self?.hide()
            }
        }
    }

    private func removeFocusDismissal() {
        if let resignActiveObserver {
            NotificationCenter.default.removeObserver(resignActiveObserver)
            self.resignActiveObserver = nil
        }
    }

    private func scheduleReviewAutoHide() {
        reviewAutoHideTask?.cancel()
        reviewAutoHideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard let self, self.isShowingReview else { return }
            self.hide()
        }
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

    private func positionReview(_ panel: NSPanel, near cursorLocation: NSPoint) {
        let size = panel.contentView?.fittingSize ?? NSSize(width: 320, height: 118)
        panel.setContentSize(size)

        let screen = NSScreen.screens.first { NSMouseInRect(cursorLocation, $0.frame, false) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let origin = NSPoint(
            x: min(max(cursorLocation.x - size.width / 2, visibleFrame.minX + 8), visibleFrame.maxX - size.width - 8),
            y: min(max(cursorLocation.y - size.height / 2, visibleFrame.minY + 8), visibleFrame.maxY - size.height - 8)
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

private struct CursorTranscriptReviewView: View {
    let text: String
    let onCopy: (String) -> Void
    let onMoveWindow: (NSEvent) -> Void
    let onDismiss: () -> Void

    @State private var editableText: String
    @State private var copiedRevision = 0
    @State private var isMoveHandleHovered = false
    @State private var isDragHandleHovered = false
    @State private var isDragStarting = false
    @State private var hasMouseEntered = false

    init(
        text: String,
        onCopy: @escaping (String) -> Void,
        onMoveWindow: @escaping (NSEvent) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.text = text
        self.onCopy = onCopy
        self.onMoveWindow = onMoveWindow
        self.onDismiss = onDismiss
        _editableText = State(initialValue: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                moveHandle

                Label("Copied", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.40, green: 0.70, blue: 0.48))

                Spacer(minLength: 8)

                Button {
                    onCopy(editableText)
                    copiedRevision += 1
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("Copy transcript")

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }

            TextEditor(text: $editableText)
                .font(.callout)
                .scrollContentBackground(.hidden)
                .frame(width: 292, height: 58)
                .padding(.horizontal, -4)
                .onChange(of: editableText) { _, newValue in
                    onCopy(newValue)
                }

            HStack(spacing: 8) {
                dragHandle

                Spacer(minLength: 8)

                Label("Press Command-V", systemImage: "command")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 320, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.primary.opacity(0.12))
        }
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .onHover { hovering in
            if hovering {
                hasMouseEntered = true
            } else if hasMouseEntered {
                onDismiss()
            }
        }
        .id(copiedRevision)
    }

    private var moveHandle: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 11, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
            Text("Move")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(isMoveHandleHovered ? Color.accentColor : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(isMoveHandleHovered ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor).opacity(0.75))
        }
        .overlay {
            Capsule()
                .strokeBorder(
                    isMoveHandleHovered ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.08),
                    lineWidth: 1
                )
        }
        .contentShape(Capsule())
        .onHover { hovering in
            isMoveHandleHovered = hovering
            if hovering {
                NSCursor.openHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard let event = NSApp.currentEvent else { return }
                    NSCursor.closedHand.set()
                    onMoveWindow(event)
                }
        )
        .help("Move review bubble")
    }

    private var dragHandle: some View {
        HStack(spacing: 6) {
            Image(systemName: isDragStarting ? "arrow.up.doc.fill" : "hand.draw")
                .font(.system(size: 12, weight: .semibold))
                .symbolRenderingMode(.hierarchical)

            Text(isDragStarting ? "Dragging" : "Drag to paste")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(isDragHandleHovered ? Color.accentColor : .secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(isDragHandleHovered ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor).opacity(0.9))
        }
        .overlay {
            Capsule()
                .strokeBorder(
                    isDragHandleHovered ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.10),
                    lineWidth: 1
                )
        }
        .contentShape(Capsule())
        .scaleEffect(isDragHandleHovered ? 1.03 : 1)
        .animation(.easeOut(duration: 0.12), value: isDragHandleHovered)
        .animation(.easeOut(duration: 0.12), value: isDragStarting)
        .onHover { hovering in
            isDragHandleHovered = hovering
            if hovering {
                NSCursor.openHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onDrag {
            NSCursor.closedHand.set()
            isDragStarting = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                onDismiss()
            }
            return NSItemProvider(object: editableText as NSString)
        }
    }
}
