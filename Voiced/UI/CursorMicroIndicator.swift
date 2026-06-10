import AppKit
import Observation
import os
import SwiftUI

@MainActor
final class CursorMicroIndicator: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var followTask: Task<Void, Never>?
    private var resignActiveObserver: NSObjectProtocol?
    private var liveCancelHandler: (() -> Void)?
    private var liveTranscriptModel: CursorLiveTranscriptModel?
    private var reviewTranscriptModel: CursorTranscriptReviewModel?
    private var isShowingReview = false
    private var isShowingLiveTranscript = false

    var hasReviewText: Bool {
        guard let text = reviewTranscriptModel?.text else { return false }
        return !LiveTranscriptState.sanitizedText(text).isEmpty
    }

    func showTranscribingAtCursor() {
        let panel = existingOrCreatePanel()
        isShowingReview = false
        isShowingLiveTranscript = false
        liveCancelHandler = nil
        liveTranscriptModel = nil
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
        removeFocusDismissal()

        let panel = existingOrCreatePanel()
        let liveTranscriptModel = CursorLiveTranscriptModel(state: state)
        let reviewModel = existingOrCreateReviewModel()
        reviewModel.mode = .listening(liveTranscriptModel)
        reviewModel.onCopy = { _ in }
        reviewModel.onDismiss = { [weak self] in
            self?.liveCancelHandler?()
        }
        reviewModel.onWindowMoved = { [weak panel, weak reviewModel] in
            guard let panel, let reviewModel else { return }
            reviewModel.anchorPoint = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        }
        self.liveTranscriptModel = liveTranscriptModel
        isShowingReview = false
        isShowingLiveTranscript = true
        liveCancelHandler = onCancel
        panel.ignoresMouseEvents = false
        installTranscriptSurfaceIfNeeded(panel: panel, model: reviewModel)
        let wasVisible = panel.isVisible && panel.alphaValue > 0
        if reviewModel.anchorPoint == nil {
            reviewModel.anchorPoint = NSEvent.mouseLocation
        }
        positionReview(panel, near: reviewModel.anchorPoint ?? NSEvent.mouseLocation)
        panel.alphaValue = wasVisible ? 1 : 0
        panel.makeKeyAndOrderFront(nil)

        if !wasVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        }
    }

    func updateLiveTranscript(_ state: LiveTranscriptState) {
        guard isShowingLiveTranscript, let panel else { return }
        if let liveTranscriptModel {
            liveTranscriptModel.state = state
        } else {
            let liveTranscriptModel = CursorLiveTranscriptModel(state: state)
            let reviewModel = existingOrCreateReviewModel()
            reviewModel.mode = .listening(liveTranscriptModel)
            reviewModel.onCopy = { _ in }
            reviewModel.onDismiss = { [weak self] in
                self?.liveCancelHandler?()
            }
            self.liveTranscriptModel = liveTranscriptModel
            installTranscriptSurfaceIfNeeded(panel: panel, model: reviewModel)
        }
        positionReview(panel, near: reviewTranscriptModel?.anchorPoint ?? NSEvent.mouseLocation)
    }

    func showReviewAtCursor(text: String, onCopy: @escaping (String) -> Void) {
        followTask?.cancel()
        followTask = nil

        let panel = existingOrCreatePanel()
        let reviewModel = existingOrUpdatedReviewModel(appending: text)
        reviewModel.mode = .editing
        reviewModel.onCopy = onCopy
        reviewModel.onDismiss = { [weak self] in
            guard self?.isShowingReview == true else { return }
            self?.hide()
        }
        reviewModel.onWindowMoved = { [weak panel, weak reviewModel] in
            guard let panel, let reviewModel else { return }
            reviewModel.anchorPoint = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        }
        onCopy(reviewModel.text)
        isShowingReview = true
        isShowingLiveTranscript = false
        liveCancelHandler = nil
        liveTranscriptModel = nil
        panel.ignoresMouseEvents = false
        let wasVisible = panel.isVisible && panel.alphaValue > 0
        installTranscriptSurfaceIfNeeded(panel: panel, model: reviewModel)
        positionReview(panel, near: reviewModel.anchorPoint ?? NSEvent.mouseLocation)
        if wasVisible {
            panel.alphaValue = 1
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.alphaValue = 0
            panel.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        }

        installFocusDismissal()
    }

    private func existingOrCreateReviewModel() -> CursorTranscriptReviewModel {
        if let reviewTranscriptModel {
            return reviewTranscriptModel
        }

        let reviewTranscriptModel = CursorTranscriptReviewModel(text: "")
        self.reviewTranscriptModel = reviewTranscriptModel
        return reviewTranscriptModel
    }

    private func installTranscriptSurfaceIfNeeded(panel: NSPanel, model: CursorTranscriptReviewModel) {
        if panel.contentView is TransparentHostingView<CursorTranscriptReviewView> {
            return
        }

        panel.contentView = TransparentHostingView(rootView: CursorTranscriptReviewView(model: model))
    }

    private func existingOrUpdatedReviewModel(appending text: String) -> CursorTranscriptReviewModel {
        let sanitizedText = LiveTranscriptState.sanitizedText(text)
        let reviewTranscriptModel = existingOrCreateReviewModel()
        reviewTranscriptModel.append(sanitizedText)
        return reviewTranscriptModel
    }

    func hide() {
        isShowingReview = false
        isShowingLiveTranscript = false
        liveCancelHandler = nil
        liveTranscriptModel = nil
        reviewTranscriptModel = nil
        removeFocusDismissal()
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
        liveTranscriptModel = nil
        reviewTranscriptModel = nil
        removeFocusDismissal()
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

        let panel = CursorPanel(contentRect: NSRect(x: 0, y: 0, width: 30, height: 22),
                                styleMask: [.borderless],
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
            width: min(max(fittingSize.width, 340), 460),
            height: min(max(fittingSize.height, 88), 380)
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

private final class CursorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct CursorMicroIndicatorView: View {
    private let accent = Color(red: 0.48, green: 0.78, blue: 0.56)
    private let confirmedInk = Color(red: 0.0, green: 0.48, blue: 0.2)
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

@MainActor
@Observable
private final class CursorLiveTranscriptModel {
    var state: LiveTranscriptState

    init(state: LiveTranscriptState) {
        self.state = state
    }
}

private struct CursorLiveTranscriptView: View {
    let model: CursorLiveTranscriptModel
    let onCancel: () -> Void

    private let accent = Color(red: 0.48, green: 0.78, blue: 0.56)
    private let confirmedInk = Color(red: 0.0, green: 0.48, blue: 0.2)
    private let transcriptBottomID = "live-transcript-bottom"
    private let transcriptMaxHeight: CGFloat = 220
    private var state: LiveTranscriptState { model.state }
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
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Cancel transcription")
            }

            liveTranscriptScroll
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .frame(width: 612, alignment: .center)
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

    private var liveTranscriptScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    transcriptContent
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)

                    Color.clear
                        .frame(height: 1)
                        .id(transcriptBottomID)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.visible)
            .frame(minHeight: 36, maxHeight: transcriptMaxHeight, alignment: .bottom)
            .onAppear {
                scrollToTranscriptBottom(proxy)
            }
            .onChange(of: confirmedText) { _, _ in
                scrollToTranscriptBottom(proxy)
            }
            .onChange(of: provisionalText) { _, _ in
                scrollToTranscriptBottom(proxy)
            }
        }
    }

    private func scrollToTranscriptBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            proxy.scrollTo(transcriptBottomID, anchor: .bottom)
        }
    }

    private var transcriptContent: Text {
        if !hasConfirmedText && !hasProvisionalText {
            return Text("Listening...")
                .foregroundStyle(.secondary)
        }

        var text = Text(confirmedText)
            .foregroundStyle(confirmedInk)
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

@MainActor
@Observable
private final class CursorTranscriptReviewModel {
    var text: String
    var mode: CursorTranscriptReviewMode = .editing
    @ObservationIgnored var anchorPoint: NSPoint?
    @ObservationIgnored var onCopy: (String) -> Void = { _ in }
    @ObservationIgnored var onDismiss: () -> Void = {}
    @ObservationIgnored var onWindowMoved: () -> Void = {}

    init(text: String) {
        self.text = text
    }

    func append(_ newText: String) {
        guard !newText.isEmpty else { return }
        guard !text.isEmpty else {
            text = newText
            return
        }

        if text.last?.isWhitespace == true || newText.first?.isWhitespace == true {
            text += newText
        } else {
            text += " " + newText
        }
    }
}

private enum CursorTranscriptReviewMode {
    case editing
    case listening(CursorLiveTranscriptModel)

    var isListening: Bool {
        if case .listening = self { return true }
        return false
    }
}

private struct CursorTranscriptReviewView: View {
    @Bindable var model: CursorTranscriptReviewModel

    @FocusState private var isEditorFocused: Bool
    @State private var isDragHandleHovered = false
    @State private var isDragStarting = false
    @State private var isWindowDragging = false
    @State private var hasMouseEntered = false

    private let accent = Color(red: 0.48, green: 0.78, blue: 0.56)
    private let confirmedInk = Color(red: 0.0, green: 0.48, blue: 0.2)
    private let logger = Logger(subsystem: "net.applification.voiced", category: "cursor-review")
    private var isListening: Bool { model.mode.isListening }

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: isListening ? "waveform.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(accent)
                    Text(isListening ? "Listening" : "Ready")
                        .font(.callout.weight(.semibold))
                }
                .frame(width: 536, height: 28, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                Text("Transcript")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if isListening {
                    liveTranscriptDisplay
                } else {
                    TextEditor(text: $model.text)
                        .font(.callout)
                        .textEditorStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .focused($isEditorFocused)
                        .frame(width: 520, height: 148)
                        .padding(8)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.68))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(isEditorFocused ? accent.opacity(0.72) : Color.primary.opacity(0.16), lineWidth: 1)
                        }
                        .onTapGesture {
                            isEditorFocused = true
                        }
                        .onChange(of: model.text) { _, newValue in
                            model.onCopy(newValue)
                        }
                }
            }

            HStack(spacing: 8) {
                dragHandle

                Spacer(minLength: 8)

                Label("Command-V", systemImage: "command")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .opacity(isListening ? 0.45 : 1)
            }
            .frame(width: 536, alignment: .leading)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        }
        .frame(width: 536, alignment: .leading)
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .frame(width: 612, alignment: .center)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        }
        .overlay(alignment: .top) {
            WindowDragRegion(
                onDragStarted: {
                    isWindowDragging = true
                    isEditorFocused = false
                },
                onDragEnded: {
                    model.onWindowMoved()
                    DispatchQueue.main.async {
                        isWindowDragging = false
                    }
                }
            )
            .frame(maxWidth: .infinity, minHeight: 76, maxHeight: 76)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.primary.opacity(0.12))
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .contentShape(Rectangle())
        .onAppear {
            logger.debug("Review bubble appeared textCharacters=\(model.text.count, privacy: .public)")
            DispatchQueue.main.async {
                isEditorFocused = !isListening
            }
        }
        .onHover { hovering in
            logger.debug("Review bubble hover=\(hovering, privacy: .public) isDragStarting=\(isDragStarting, privacy: .public)")
            if hovering {
                hasMouseEntered = true
            } else if hasMouseEntered && !isDragStarting && !isWindowDragging && !isListening {
                logger.debug("Review bubble dismissed after mouse exit")
                model.onDismiss()
            } else if isDragStarting || isWindowDragging {
                logger.debug("Review bubble mouse exit ignored during drag")
            }
        }
    }

    private var liveTranscriptDisplay: some View {
        ScrollView(.vertical) {
            liveTranscriptContent
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(width: 520, height: 148, alignment: .topLeading)
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var liveTranscriptContent: Text {
        guard case .listening(let liveModel) = model.mode else {
            return Text(model.text).foregroundStyle(.primary)
        }

        let baseText = LiveTranscriptState.sanitizedText(model.text)
        let confirmedText = LiveTranscriptState.sanitizedText(liveModel.state.committedText)
        let provisionalText = LiveTranscriptState.sanitizedText(liveModel.state.provisionalText)
        if baseText.isEmpty && confirmedText.isEmpty && provisionalText.isEmpty {
            return Text("Listening...")
                .foregroundStyle(.secondary)
        }

        var text = Text(baseText)
            .foregroundStyle(.primary)
        if !baseText.isEmpty && (!confirmedText.isEmpty || !provisionalText.isEmpty) {
            text = text + Text(" ")
        }
        if !confirmedText.isEmpty {
            text = text + Text(confirmedText)
                .foregroundStyle(confirmedInk)
        }
        if !confirmedText.isEmpty && !provisionalText.isEmpty {
            text = text + Text(" ")
        }
        if !provisionalText.isEmpty {
            text = text + Text(provisionalText)
                .foregroundStyle(.primary)
        }
        return text
    }

    private var isDragHandleActive: Bool {
        !isListening && (isDragHandleHovered || isDragStarting)
    }

    private var dragHandleForeground: Color {
        if isListening {
            return .secondary.opacity(0.65)
        }
        return isDragHandleActive ? .white : .secondary
    }

    private var dragHandleFill: Color {
        if isListening {
            return Color(nsColor: .controlBackgroundColor).opacity(0.55)
        }
        return isDragHandleActive ? accent : Color(nsColor: .controlBackgroundColor).opacity(0.82)
    }

    private var dragHandleStroke: Color {
        isDragHandleActive ? accent.opacity(0.82) : Color.primary.opacity(0.10)
    }

    private var dragHandleStrokeWidth: CGFloat {
        isDragHandleActive ? 1.5 : 1
    }

    private var dragHandle: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.draw")
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.hierarchical)

            Text("Drag to paste")
                .font(.callout.weight(.semibold))
        }
        .foregroundStyle(dragHandleForeground)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(dragHandleFill)
        }
        .overlay {
            Capsule()
                .strokeBorder(dragHandleStroke, lineWidth: dragHandleStrokeWidth)
        }
        .contentShape(Capsule())
        .scaleEffect(isDragHandleHovered && !isListening ? 1.03 : 1)
        .animation(.easeOut(duration: 0.12), value: isDragHandleHovered)
        .animation(.easeOut(duration: 0.12), value: isDragStarting)
        .onHover { hovering in
            isDragHandleHovered = hovering
            logger.debug("Drag handle hover=\(hovering, privacy: .public) textCharacters=\(model.text.count, privacy: .public)")
            if hovering && !isListening {
                NSCursor.openHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .overlay {
            if !isListening {
                TextDragSourceView(
                    text: model.text,
                    onHoverChanged: { hovering in
                        isDragHandleHovered = hovering
                        logger.debug("Drag source hover=\(hovering, privacy: .public) textCharacters=\(model.text.count, privacy: .public)")
                    },
                    onPressChanged: { pressing in
                        isDragStarting = pressing
                    },
                    onDragStarted: {
                        NSCursor.closedHand.set()
                        isDragStarting = true
                        model.onCopy(model.text)
                        logger.debug("Drag started textCharacters=\(model.text.count, privacy: .public)")
                    },
                    onDragEnded: { operation in
                        logger.debug("Drag ended operation=\(operation.rawValue, privacy: .public)")
                        isDragStarting = false
                        if operation != [] {
                            model.onDismiss()
                        }
                    }
                )
            }
        }
    }

}

private struct WindowDragRegion: NSViewRepresentable {
    let onDragStarted: () -> Void
    let onDragEnded: () -> Void

    func makeNSView(context: Context) -> WindowDragRegionNSView {
        WindowDragRegionNSView(onDragStarted: onDragStarted, onDragEnded: onDragEnded)
    }

    func updateNSView(_ view: WindowDragRegionNSView, context: Context) {
        view.onDragStarted = onDragStarted
        view.onDragEnded = onDragEnded
    }
}

private final class WindowDragRegionNSView: NSView {
    var onDragStarted: () -> Void
    var onDragEnded: () -> Void
    private var dragStartLocation: NSPoint?
    private var dragStartOrigin: NSPoint?
    private var trackingArea: NSTrackingArea?

    init(onDragStarted: @escaping () -> Void, onDragEnded: @escaping () -> Void) {
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

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.openHand.set()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.openHand.set()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragStartLocation = NSEvent.mouseLocation
        dragStartOrigin = window.frame.origin
        onDragStarted()
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let dragStartLocation, let dragStartOrigin else { return }
        let currentLocation = NSEvent.mouseLocation
        let delta = NSPoint(
            x: currentLocation.x - dragStartLocation.x,
            y: currentLocation.y - dragStartLocation.y
        )
        window.setFrameOrigin(NSPoint(
            x: dragStartOrigin.x + delta.x,
            y: dragStartOrigin.y + delta.y
        ))
    }

    override func mouseUp(with event: NSEvent) {
        guard dragStartLocation != nil else { return }
        dragStartLocation = nil
        dragStartOrigin = nil
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            NSCursor.openHand.set()
        } else {
            NSCursor.arrow.set()
        }
        onDragEnded()
    }
}

private struct TextDragSourceView: NSViewRepresentable {
    let text: String
    let onHoverChanged: (Bool) -> Void
    let onPressChanged: (Bool) -> Void
    let onDragStarted: () -> Void
    let onDragEnded: (NSDragOperation) -> Void

    func makeNSView(context: Context) -> TextDragSourceNSView {
        TextDragSourceNSView(
            text: text,
            onHoverChanged: onHoverChanged,
            onPressChanged: onPressChanged,
            onDragStarted: onDragStarted,
            onDragEnded: onDragEnded
        )
    }

    func updateNSView(_ view: TextDragSourceNSView, context: Context) {
        view.text = text
        view.onHoverChanged = onHoverChanged
        view.onPressChanged = onPressChanged
        view.onDragStarted = onDragStarted
        view.onDragEnded = onDragEnded
    }
}

private final class TextDragSourceNSView: NSView, NSDraggingSource {
    var text: String
    var onHoverChanged: (Bool) -> Void
    var onPressChanged: (Bool) -> Void
    var onDragStarted: () -> Void
    var onDragEnded: (NSDragOperation) -> Void
    private var hasStartedDrag = false
    private var trackingArea: NSTrackingArea?
    private var dragFileURL: URL?

    init(
        text: String,
        onHoverChanged: @escaping (Bool) -> Void,
        onPressChanged: @escaping (Bool) -> Void,
        onDragStarted: @escaping () -> Void,
        onDragEnded: @escaping (NSDragOperation) -> Void
    ) {
        self.text = text
        self.onHoverChanged = onHoverChanged
        self.onPressChanged = onPressChanged
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

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.openHand.set()
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged(true)
        NSCursor.openHand.set()
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged(false)
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        hasStartedDrag = false
        onPressChanged(true)
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard !hasStartedDrag else { return }
        hasStartedDrag = true
        onDragStarted()

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(text, forType: .string)
        if let fileURL = makeDragFile() {
            pasteboardItem.setString(fileURL.absoluteString, forType: .fileURL)
        }

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(bounds, contents: dragImage())
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        hasStartedDrag = false
        onPressChanged(false)
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            NSCursor.openHand.set()
        } else {
            NSCursor.arrow.set()
        }
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
        onPressChanged(false)
        if operation == [] {
            fallbackPaste(at: screenPoint)
        }
        cleanupDragFile()
        onDragEnded(operation)
    }

    private func makeDragFile() -> URL? {
        cleanupDragFile()

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Voiced Transcript")
            .appendingPathExtension("txt")
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            dragFileURL = fileURL
            return fileURL
        } catch {
            return nil
        }
    }

    private func cleanupDragFile() {
        guard let dragFileURL else { return }
        try? FileManager.default.removeItem(at: dragFileURL)
        self.dragFileURL = nil
    }

    private func fallbackPaste(at screenPoint: NSPoint) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let eventPoint = Self.quartzPoint(from: screenPoint)
        let source = CGEventSource(stateID: .hidSystemState)
        let mouseDown = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseDown,
            mouseCursorPosition: eventPoint,
            mouseButton: .left
        )
        let mouseUp = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: eventPoint,
            mouseButton: .left
        )
        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            let source = CGEventSource(stateID: .hidSystemState)
            let keyCodeV: CGKeyCode = 9
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: false)
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }

    private static func quartzPoint(from appKitPoint: NSPoint) -> CGPoint {
        let screen = NSScreen.screens.first { $0.frame.contains(appKitPoint) } ?? NSScreen.main
        guard let screen else { return appKitPoint }
        return CGPoint(
            x: appKitPoint.x,
            y: screen.frame.maxY - appKitPoint.y + screen.frame.minY
        )
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
