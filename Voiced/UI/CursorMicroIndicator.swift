import AppKit
import os
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class CursorMicroIndicator: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var followTask: Task<Void, Never>?
    private var reviewAutoHideTask: Task<Void, Never>?
    private var resignActiveObserver: NSObjectProtocol?
    private var liveCancelHandler: (() -> Void)?
    private var isShowingReview = false
    private var isShowingLiveTranscript = false

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

    func showLiveTranscriptAtCursor(state: LiveTranscriptState, onCancel: @escaping () -> Void) {
        reviewAutoHideTask?.cancel()
        reviewAutoHideTask = nil
        removeFocusDismissal()

        let panel = existingOrCreatePanel()
        isShowingReview = false
        isShowingLiveTranscript = true
        liveCancelHandler = onCancel
        panel.ignoresMouseEvents = false
        panel.contentView = TransparentHostingView(
            rootView: CursorLiveTranscriptView(
                state: state,
                onCancel: onCancel
            )
        )
        positionLiveTranscript(panel, near: NSEvent.mouseLocation)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        startFollowingLiveTranscript(panel)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func updateLiveTranscript(_ state: LiveTranscriptState) {
        guard isShowingLiveTranscript, let panel else { return }
        panel.contentView = TransparentHostingView(
            rootView: CursorLiveTranscriptView(
                state: state,
                onCancel: { [weak self] in
                    self?.liveCancelHandler?()
                }
            )
        )
        positionLiveTranscript(panel, near: NSEvent.mouseLocation)
    }

    func showReviewAtCursor(text: String, onCopy: @escaping (String) -> Void) {
        followTask?.cancel()
        followTask = nil
        reviewAutoHideTask?.cancel()

        let panel = existingOrCreatePanel()
        isShowingReview = true
        isShowingLiveTranscript = false
        liveCancelHandler = nil
        panel.ignoresMouseEvents = false
        let wasVisible = panel.isVisible && panel.alphaValue > 0
        panel.contentView = TransparentHostingView(
            rootView: CursorTranscriptReviewView(
                text: text,
                onCopy: onCopy,
                onDismiss: { [weak self] in
                    self?.hide()
                }
            )
        )
        positionReview(panel, near: NSEvent.mouseLocation)
        if wasVisible {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        } else {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        }

        installFocusDismissal()
        scheduleReviewAutoHide()
    }

    func hide() {
        isShowingReview = false
        isShowingLiveTranscript = false
        liveCancelHandler = nil
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
        isShowingLiveTranscript = false
        liveCancelHandler = nil
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

    private func startFollowingLiveTranscript(_ panel: NSPanel) {
        followTask?.cancel()
        followTask = Task { @MainActor [weak self, weak panel] in
            while !Task.isCancelled {
                guard let self, let panel, panel.isVisible, self.isShowingLiveTranscript else { break }
                self.positionLiveTranscript(panel, near: NSEvent.mouseLocation)
                try? await Task.sleep(nanoseconds: 80_000_000)
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

    private func positionLiveTranscript(_ panel: NSPanel, near cursorLocation: NSPoint) {
        let fittingSize = panel.contentView?.fittingSize ?? NSSize(width: 340, height: 104)
        let size = NSSize(
            width: min(max(fittingSize.width, 300), 360),
            height: min(max(fittingSize.height, 88), 260)
        )
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
    private let logger = Logger(subsystem: "net.applification.voiced", category: "cursor-review")

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

private struct CursorLiveTranscriptView: View {
    let state: LiveTranscriptState
    let onCancel: () -> Void

    private let accent = Color(red: 0.48, green: 0.78, blue: 0.56)
    private let confirmedInk = Color(red: 0.0, green: 0.48, blue: 0.2)
    private var confirmedText: String { LiveTranscriptState.sanitizedText(state.committedText) }
    private var provisionalText: String { LiveTranscriptState.sanitizedText(state.provisionalText) }
    private var hasConfirmedText: Bool { !confirmedText.isEmpty }
    private var hasProvisionalText: Bool { !provisionalText.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                HStack(alignment: .center, spacing: 6) {
                    LiveTranscriptStatusIcon(
                        isRecording: state.isRecording,
                        hasConfirmedText: hasConfirmedText,
                        hasProvisionalText: hasProvisionalText,
                        accent: accent
                    )
                    Text(state.isRecording ? "Listening" : "Finishing")
                        .font(.caption.weight(.semibold))
                }

                Spacer(minLength: 8)

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Cancel transcription")
            }

            transcriptContent
                .font(.callout)
                .lineLimit(8)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.16), value: confirmedText)
                .animation(.easeOut(duration: 0.2), value: provisionalText)
        }
        .padding(12)
        .frame(width: 340, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.primary.opacity(0.12))
        }
        .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
    }


    private var transcriptContent: Text {
        if !hasConfirmedText && !hasProvisionalText {
            return Text("Listening...")
                .foregroundStyle(.secondary)
        }

        var text = Text(confirmedText)
            .foregroundStyle(confirmedInk)
            .fontWeight(.bold)
        if hasConfirmedText && hasProvisionalText {
            text = text + Text(" ")
        }
        if hasProvisionalText {
            let provisional = Text(provisionalText)
                .foregroundStyle(.primary)
                .fontWeight(.regular)
            text = text + provisional
        }
        return text
    }

}

private struct LiveTranscriptStatusIcon: View {
    let isRecording: Bool
    let hasConfirmedText: Bool
    let hasProvisionalText: Bool
    let accent: Color

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accent.opacity(hasProvisionalText ? 1 : 0.82))
                .contentTransition(.symbolEffect(.replace))

            if hasConfirmedText {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 7, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(accent)
                    .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
                    .transition(.scale.combined(with: .opacity))
            } else if isRecording && hasProvisionalText {
                LivePulseDot(accent: accent)
            }
        }
        .frame(width: 16, height: 16)
    }
}

private struct LivePulseDot: View {
    let accent: Color

    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(accent)
            .frame(width: 5, height: 5)
            .scaleEffect(isPulsing ? 1.35 : 0.72)
            .opacity(isPulsing ? 0.45 : 1)
            .animation(.easeOut(duration: 0.62).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                isPulsing = true
            }
    }
}

private struct CursorTranscriptReviewView: View {
    let text: String
    let onCopy: (String) -> Void
    let onDismiss: () -> Void

    @State private var editableText: String
    @State private var copiedRevision = 0
    @State private var isDragHandleHovered = false
    @State private var isDragStarting = false
    @State private var hasMouseEntered = false

    private let accent = Color(red: 0.48, green: 0.78, blue: 0.56)
    private let logger = Logger(subsystem: "net.applification.voiced", category: "cursor-review")

    init(
        text: String,
        onCopy: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.text = text
        self.onCopy = onCopy
        self.onDismiss = onDismiss
        _editableText = State(initialValue: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(accent)
                    Text("Ready")
                        .font(.caption.weight(.semibold))
                }

                Spacer(minLength: 8)

                Button {
                    onCopy(editableText)
                    copiedRevision += 1
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Copy transcript")

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }

            TextEditor(text: $editableText)
                .font(.callout)
                .scrollContentBackground(.hidden)
                .frame(width: 316, height: 74)
                .padding(.horizontal, -4)
                .onChange(of: editableText) { _, newValue in
                    onCopy(newValue)
                }

            HStack(spacing: 8) {
                dragHandle

                Spacer(minLength: 8)

                Label("Command-V", systemImage: "command")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .padding(12)
        .frame(width: 340, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.primary.opacity(0.12))
        }
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .onAppear {
            logger.debug("Review bubble appeared textCharacters=\(editableText.count, privacy: .public)")
        }
        .onHover { hovering in
            logger.debug("Review bubble hover=\(hovering, privacy: .public) isDragStarting=\(isDragStarting, privacy: .public)")
            if hovering {
                hasMouseEntered = true
            } else if hasMouseEntered && !isDragStarting {
                logger.debug("Review bubble dismissed after mouse exit")
                onDismiss()
            } else if isDragStarting {
                logger.debug("Review bubble mouse exit ignored during drag")
            }
        }
        .id(copiedRevision)
    }

    private var dragHandle: some View {
        HStack(spacing: 6) {
            Image(systemName: isDragStarting ? "arrow.up.doc.fill" : "hand.draw")
                .font(.system(size: 12, weight: .semibold))
                .symbolRenderingMode(.hierarchical)

            Text(isDragStarting ? "Dragging" : "Drag to paste")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(isDragHandleHovered ? accent : .secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(isDragHandleHovered ? accent.opacity(0.12) : Color(nsColor: .controlBackgroundColor).opacity(0.9))
        }
        .overlay {
            Capsule()
                .strokeBorder(
                    isDragHandleHovered ? accent.opacity(0.55) : Color.primary.opacity(0.10),
                    lineWidth: 1
                )
        }
        .contentShape(Capsule())
        .scaleEffect(isDragHandleHovered ? 1.03 : 1)
        .animation(.easeOut(duration: 0.12), value: isDragHandleHovered)
        .animation(.easeOut(duration: 0.12), value: isDragStarting)
        .onHover { hovering in
            isDragHandleHovered = hovering
            logger.debug("Drag handle hover=\(hovering, privacy: .public) textCharacters=\(editableText.count, privacy: .public)")
            if hovering {
                NSCursor.openHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .overlay {
            TextDragSourceView(
                text: editableText,
                onDragStarted: {
                    NSCursor.closedHand.set()
                    isDragStarting = true
                    onCopy(editableText)
                    logger.debug("Drag started textCharacters=\(editableText.count, privacy: .public)")
                },
                onDragEnded: { operation in
                    logger.debug("Drag ended operation=\(operation.rawValue, privacy: .public)")
                    isDragStarting = false
                    if operation != [] {
                        onDismiss()
                    }
                }
            )
        }
    }

}

private struct TextDragSourceView: NSViewRepresentable {
    let text: String
    let onDragStarted: () -> Void
    let onDragEnded: (NSDragOperation) -> Void

    func makeNSView(context: Context) -> TextDragSourceNSView {
        TextDragSourceNSView(
            text: text,
            onDragStarted: onDragStarted,
            onDragEnded: onDragEnded
        )
    }

    func updateNSView(_ view: TextDragSourceNSView, context: Context) {
        view.text = text
        view.onDragStarted = onDragStarted
        view.onDragEnded = onDragEnded
    }
}

private final class TextDragSourceNSView: NSView, NSDraggingSource {
    var text: String
    var onDragStarted: () -> Void
    var onDragEnded: (NSDragOperation) -> Void
    private var hasStartedDrag = false

    init(
        text: String,
        onDragStarted: @escaping () -> Void,
        onDragEnded: @escaping (NSDragOperation) -> Void
    ) {
        self.text = text
        self.onDragStarted = onDragStarted
        self.onDragEnded = onDragEnded
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        hasStartedDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !hasStartedDrag else { return }
        hasStartedDrag = true
        onDragStarted()

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(text, forType: .string)
        pasteboardItem.setString(text, forType: NSPasteboard.PasteboardType(UTType.text.identifier))
        pasteboardItem.setString(text, forType: NSPasteboard.PasteboardType(UTType.plainText.identifier))
        pasteboardItem.setString(text, forType: NSPasteboard.PasteboardType(UTType.utf8PlainText.identifier))

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(bounds, contents: dragImage())
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        hasStartedDrag = false
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        hasStartedDrag = false
        onDragEnded(operation)
    }

    private func dragImage() -> NSImage {
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        NSColor.controlAccentColor.withAlphaComponent(0.16).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2).fill()
        image.unlockFocus()
        return image
    }
}
