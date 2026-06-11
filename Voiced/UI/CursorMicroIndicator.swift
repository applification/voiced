import AppKit
import Observation
import SwiftUI

@MainActor
final class CursorMicroIndicator: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var followTask: Task<Void, Never>?
    private var resignActiveObserver: NSObjectProtocol?
    private var liveCancelHandler: (() -> Void)?
    private var liveTranscriptModel: CursorLiveTranscriptModel?
    private var lastLiveTranscriptState: LiveTranscriptState?
    private var reviewTranscriptModel: CursorTranscriptReviewModel?
    private let audioLevelModel = AudioLevelModel()
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
        lastLiveTranscriptState = nil
        audioLevelModel.level = 0
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
        reviewModel.audioLevelModel = audioLevelModel
        audioLevelModel.level = state.audioLevel
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
        lastLiveTranscriptState = state
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
        guard lastLiveTranscriptState != state else { return }
        lastLiveTranscriptState = state
        if let liveTranscriptModel {
            liveTranscriptModel.state = state
        } else {
            let liveTranscriptModel = CursorLiveTranscriptModel(state: state)
            let reviewModel = existingOrCreateReviewModel()
            reviewModel.audioLevelModel = audioLevelModel
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

    func updateAudioLevel(_ level: Double) {
        guard isShowingLiveTranscript else { return }
        audioLevelModel.level = level
    }

    func showReviewAtCursor(
        text: String,
        onCopy: @escaping (String) -> Void,
        onProcess: @escaping (TranscriptProcessingProfile, String) async -> String,
        onLoadReminderLists: @escaping (Bool) async -> [ReminderListOption],
        onExportToReminders: @escaping (String, String?) async -> ReminderExportResult,
        onDropRejected: @escaping () -> Void
    ) {
        followTask?.cancel()
        followTask = nil

        let panel = existingOrCreatePanel()
        let reviewModel = existingOrUpdatedReviewModel(appending: text)
        reviewModel.mode = .editing
        reviewModel.onCopy = onCopy
        reviewModel.onProcess = onProcess
        reviewModel.onLoadReminderLists = onLoadReminderLists
        reviewModel.onExportToReminders = onExportToReminders
        reviewModel.onDropRejected = onDropRejected
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
        lastLiveTranscriptState = nil
        audioLevelModel.level = 0
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
        resetReviewCursor()
        clearReviewFirstResponder(in: panel)

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

        let hostingView = TransparentHostingView(rootView: CursorTranscriptReviewView(model: model))
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 22
        hostingView.layer?.masksToBounds = true
        panel.contentView = hostingView
    }

    private func resetReviewCursor() {
        NSCursor.arrow.set()
    }

    private func clearReviewFirstResponder(in panel: NSPanel) {
        DispatchQueue.main.async { [weak panel] in
            panel?.makeFirstResponder(nil)
            NSCursor.arrow.set()
        }
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
        lastLiveTranscriptState = nil
        reviewTranscriptModel = nil
        audioLevelModel.level = 0
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
        lastLiveTranscriptState = nil
        reviewTranscriptModel = nil
        audioLevelModel.level = 0
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
        panel.hasShadow = true
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
        if panel.frame.size != size {
            panel.setContentSize(size)
        }

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
        if panel.frame.size != size {
            panel.setContentSize(size)
        }

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

@MainActor
@Observable
private final class CursorTranscriptReviewModel {
    var text: String
    var mode: CursorTranscriptReviewMode = .editing
    var processingProfile: TranscriptProcessingProfile?
    var isExportingToReminders = false
    var isLoadingReminderLists = false
    var reminderLists: [ReminderListOption] = []
    var reminderExportMessage: String?
    @ObservationIgnored var audioLevelModel = AudioLevelModel()
    @ObservationIgnored var anchorPoint: NSPoint?
    @ObservationIgnored var onCopy: (String) -> Void = { _ in }
    @ObservationIgnored var onProcess: (TranscriptProcessingProfile, String) async -> String = { _, transcript in transcript }
    @ObservationIgnored var onLoadReminderLists: (Bool) async -> [ReminderListOption] = { _ in [] }
    @ObservationIgnored var onExportToReminders: (String, String?) async -> ReminderExportResult = { _, _ in .failure("Reminders export is unavailable.") }
    @ObservationIgnored var onDismiss: () -> Void = {}
    @ObservationIgnored var onDropRejected: () -> Void = {}
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
    @State private var didRejectLastDrop = false
    @State private var hoveredTranscriptAction: TranscriptProcessingProfile?
    @State private var isReminderExportHovered = false

    private let accent = Color.primary
    private let aiAccent = Color(nsColor: .systemPurple)
    private let confirmedInk = Color.primary
    private let statusAccent = Color(red: 0.48, green: 0.78, blue: 0.56)
    private let warningInk = Color(red: 0.78, green: 0.23, blue: 0.06)
    private let panelWidth: CGFloat = 624
    private let contentWidth: CGFloat = 560
    private let editorHeight: CGFloat = 172
    private let liveTranscriptBottomID = "cursor-live-transcript-bottom"
    private var isListening: Bool { model.mode.isListening }
    private var isProcessing: Bool { model.processingProfile != nil }
    private var isAIProcessing: Bool { isProcessing }
    private var isBusy: Bool { isAIProcessing || model.isExportingToReminders }
    private var canProcessTranscript: Bool {
        !isListening && !isBusy && !LiveTranscriptState.sanitizedText(model.text).isEmpty
    }
    private var reminderTaskCount: Int {
        ReminderChecklistParser.taskCount(in: model.text)
    }
    private var canExportToReminders: Bool {
        !isListening && !isBusy && reminderTaskCount > 0
    }
    private var transcriptWordCount: Int {
        LiveTranscriptState.sanitizedText(model.text)
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }
    private var liveAudioLevelModel: AudioLevelModel {
        model.audioLevelModel
    }

    private var panelFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor).opacity(0.99),
                Color(nsColor: .controlBackgroundColor).opacity(0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            panelHeader
            transcriptSurface
            commandBar
        }
        .frame(width: contentWidth, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(width: panelWidth, alignment: .center)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(panelFill)
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
            .frame(maxWidth: .infinity, minHeight: 70, maxHeight: 70)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        .shadow(color: .black.opacity(0.16), radius: 36, y: 30)
        .shadow(color: .black.opacity(0.12), radius: 76, y: 46)
        .contentShape(Rectangle())
        .onAppear {
            isEditorFocused = false
        }
        .onChange(of: isListening) { _, listening in
            if listening {
                isEditorFocused = false
            }
        }
        .onHover { hovering in
            if hovering {
                hasMouseEntered = true
                if !isEditorFocused && !isDragHandleHovered && !isDragStarting {
                    NSCursor.arrow.set()
                }
            } else if hasMouseEntered && !isDragStarting && !isWindowDragging && !isListening && !isBusy {
                model.onDismiss()
            }
        }
    }

    private var panelHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusFill)
                    .frame(width: 34, height: 34)
                CursorHeaderStatusIcon(
                    isListening: isListening,
                    isProcessing: isAIProcessing,
                    audioLevelModel: liveAudioLevelModel,
                    accent: statusColor,
                    processingAccent: aiAccent
                )
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(headerTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if !isListening {
                Text(transcriptWordCount == 1 ? "1 word" : "\(transcriptWordCount) words")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background {
                        Capsule()
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.54))
                    }
            }
        }
        .frame(width: contentWidth, height: 38, alignment: .leading)
    }

    private var transcriptSurface: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcript")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                if isListening {
                    liveTranscriptDisplay
                } else {
                    transcriptEditor
                }
            }
        }
    }

    private var transcriptEditor: some View {
        TextEditor(text: $model.text)
            .font(.system(.body, design: .default))
            .lineSpacing(3)
            .textEditorStyle(.plain)
            .disabled(isAIProcessing)
            .scrollContentBackground(.hidden)
            .focused($isEditorFocused)
            .frame(width: contentWidth - 22, height: editorHeight)
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(nsColor: .controlBackgroundColor).opacity(0.82),
                                Color(nsColor: .windowBackgroundColor).opacity(0.64)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(editorStrokeColor, lineWidth: isEditorFocused ? 1.5 : 1)
            }
            .opacity(isAIProcessing ? 0.58 : 1)
            .animation(.easeOut(duration: 0.16), value: isAIProcessing)
            .onTapGesture {
                isEditorFocused = true
            }
            .onChange(of: model.text) { _, newValue in
                model.reminderExportMessage = nil
                model.onCopy(newValue)
            }
    }

    private var liveTranscriptDisplay: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    liveTranscriptContent
                        .font(.system(.body, design: .default))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 5)
                        .padding(.top, 0)
                        .padding(.bottom, 10)
                        .textSelection(.enabled)

                    Color.clear
                        .frame(height: 1)
                        .id(liveTranscriptBottomID)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear {
                scrollLiveTranscriptToBottom(proxy)
            }
            .onChange(of: liveTranscriptScrollText) { _, _ in
                scrollLiveTranscriptToBottom(proxy)
            }
        }
        .frame(width: contentWidth - 22, height: editorHeight, alignment: .topLeading)
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.42))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(nsColor: .controlBackgroundColor).opacity(0.42), lineWidth: 1)
        }
    }

    private var liveTranscriptScrollText: String {
        guard case .listening(let liveModel) = model.mode else {
            return model.text
        }

        return [
            LiveTranscriptState.sanitizedText(model.text),
            LiveTranscriptState.sanitizedText(liveModel.state.committedText),
            LiveTranscriptState.sanitizedText(liveModel.state.provisionalText)
        ].joined(separator: " ")
    }

    private func scrollLiveTranscriptToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            proxy.scrollTo(liveTranscriptBottomID, anchor: .bottom)
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
                .foregroundStyle(.secondary)
                .italic()
        }
        return text
    }

    private var commandBar: some View {
        HStack(alignment: .center, spacing: 10) {
            if !isListening {
                HStack(spacing: 6) {
                    transcriptActionButton(profile: .cleanTranscript, title: "Clean", symbolName: "wand.and.sparkles")
                    transcriptActionButton(profile: .executiveSummary, title: "Summarize", symbolName: "text.badge.checkmark")
                    transcriptActionButton(profile: .todoList, title: "To-do", symbolName: "checklist")
                    if reminderTaskCount > 0 {
                        remindersExportButton
                    }
                }
                .padding(4)
                .background {
                    Capsule()
                        .fill(Color.primary.opacity(0.055))
                }
            }

            Spacer(minLength: 12)

            transcriptStatus
            dragHandle
        }
        .frame(width: contentWidth, height: 42, alignment: .center)
    }

    private var isDragHandleActive: Bool {
        !isListening && !isAIProcessing && (isDragHandleHovered || isDragStarting)
    }

    private var dragHandleForeground: Color {
        if isListening || isAIProcessing {
            return .secondary.opacity(0.65)
        }
        return .primary
    }

    private var dragHandleFill: Color {
        if isListening || isAIProcessing {
            return Color(nsColor: .controlBackgroundColor).opacity(0.58)
        }
        return isDragHandleActive
            ? Color(nsColor: .controlBackgroundColor).opacity(0.86)
            : Color(nsColor: .controlBackgroundColor).opacity(0.68)
    }

    private var dragHandleStroke: Color {
        isDragHandleActive ? Color.primary.opacity(0.20) : Color.primary.opacity(0.10)
    }

    private var dragHandleStrokeWidth: CGFloat {
        isDragHandleActive ? 1.5 : 1
    }

    @ViewBuilder
    private var transcriptStatus: some View {
        if let reminderExportMessage = model.reminderExportMessage {
            Label(reminderExportMessage, systemImage: reminderExportMessage.hasPrefix("Added") ? "checkmark.circle" : "exclamationmark.triangle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(reminderExportMessage.hasPrefix("Added") ? .secondary : warningInk)
                .lineLimit(1)
        } else if didRejectLastDrop {
            Label("Press ⌘V", systemImage: "exclamationmark.triangle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(warningInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(warningInk.opacity(0.12))
                }
        } else {
            HStack(spacing: 6) {
                Text("Paste with")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 2) {
                    Text("⌘")
                    Text("V")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.82))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                }
            }
            .opacity(isListening ? 0.45 : 1)
        }
    }

    private var remindersExportButton: some View {
        let isHovered = isReminderExportHovered && canExportToReminders
        return Menu {
            Button("Default List") {
                exportToReminders(listID: nil)
            }

            if !model.reminderLists.isEmpty {
                Divider()
                ForEach(model.reminderLists) { list in
                    Button(list.isDefault ? "\(list.title) (Default)" : list.title) {
                        exportToReminders(listID: list.id)
                    }
                }
            } else {
                Divider()
                Button(model.isLoadingReminderLists ? "Loading Lists..." : "Load Lists") {
                    loadReminderLists(requestingAccess: true)
                }
                .disabled(model.isLoadingReminderLists)
            }
        } label: {
            Label("Reminders", systemImage: model.isExportingToReminders ? "hourglass" : "list.bullet.clipboard")
                .font(.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .contentShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .foregroundStyle(canExportToReminders ? Color.primary : Color.secondary)
        .background {
            Capsule()
                .fill(transcriptActionFill(isHovered: isHovered))
        }
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(isHovered ? 0.16 : 0.08), lineWidth: 1)
        }
        .onHover { hovering in
            isReminderExportHovered = hovering && canExportToReminders
        }
        .animation(.easeOut(duration: 0.12), value: isReminderExportHovered)
        .disabled(!canExportToReminders)
        .help("Export checklist items to Reminders")
        .task(id: reminderTaskCount) {
            guard reminderTaskCount > 0 else { return }
            await loadReminderListsIfAvailable()
        }
    }

    private func transcriptActionButton(profile: TranscriptProcessingProfile, title: String, symbolName: String) -> some View {
        let isHovered = hoveredTranscriptAction == profile
        return Button {
            runTranscriptAction(profile)
        } label: {
            Label(title, systemImage: symbolName)
                .font(.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(transcriptActionForeground(isHovered: isHovered))
        .background {
            Capsule()
                .fill(transcriptActionFill(isHovered: isHovered))
        }
        .overlay {
            Capsule()
                .strokeBorder(transcriptActionStroke(isHovered: isHovered), lineWidth: 1)
        }
        .shadow(
            color: Color.black.opacity(isHovered && canProcessTranscript ? 0.22 : 0),
            radius: isHovered && canProcessTranscript ? 6 : 0,
            y: isHovered && canProcessTranscript ? 2 : 0
        )
        .onHover { hovering in
            hoveredTranscriptAction = hovering && canProcessTranscript ? profile : nil
        }
        .animation(.easeOut(duration: 0.14), value: hoveredTranscriptAction)
        .disabled(!canProcessTranscript)
        .help(profile.detail)
    }

    private func transcriptActionForeground(isHovered: Bool) -> Color {
        guard canProcessTranscript else { return Color.secondary }
        return isHovered ? Color.primary : Color.primary.opacity(0.86)
    }

    private func transcriptActionFill(isHovered: Bool) -> Color {
        guard canProcessTranscript else { return Color.clear }
        return isHovered
            ? Color(nsColor: .controlBackgroundColor).opacity(1.0)
            : Color(nsColor: .controlBackgroundColor).opacity(0.70)
    }

    private func transcriptActionStroke(isHovered: Bool) -> Color {
        guard canProcessTranscript else { return Color.primary.opacity(0.08) }
        return Color.primary.opacity(isHovered ? 0.26 : 0.08)
    }

    private func runTranscriptAction(_ profile: TranscriptProcessingProfile) {
        guard canProcessTranscript else { return }
        let sourceText = model.text
        model.processingProfile = profile
        model.reminderExportMessage = nil
        isEditorFocused = false
        Task { @MainActor in
            let processedText = await model.onProcess(profile, sourceText)
            guard model.processingProfile == profile else { return }
            model.text = processedText
            model.onCopy(processedText)
            model.processingProfile = nil
            isEditorFocused = true
        }
    }

    private func loadReminderLists(requestingAccess: Bool) {
        guard !model.isLoadingReminderLists else { return }
        model.isLoadingReminderLists = true
        Task { @MainActor in
            let lists = await model.onLoadReminderLists(requestingAccess)
            model.reminderLists = lists
            model.isLoadingReminderLists = false
        }
    }

    private func loadReminderListsIfAvailable() async {
        guard !model.isLoadingReminderLists, model.reminderLists.isEmpty else { return }
        model.isLoadingReminderLists = true
        let lists = await model.onLoadReminderLists(false)
        model.reminderLists = lists
        model.isLoadingReminderLists = false
    }

    private func exportToReminders(listID: String?) {
        guard canExportToReminders else { return }
        let sourceText = model.text
        model.isExportingToReminders = true
        model.reminderExportMessage = nil
        isEditorFocused = false
        Task { @MainActor in
            let result = await model.onExportToReminders(sourceText, listID)
            switch result {
            case .success(let count):
                model.reminderExportMessage = count == 1 ? "Added 1 reminder" : "Added \(count) reminders"
            case .failure(let message):
                model.reminderExportMessage = message
            }
            model.isExportingToReminders = false
            isEditorFocused = true
            if !model.reminderLists.isEmpty {
                await loadReminderListsIfAvailable()
            }
        }
    }

    private func processingTitle(for profile: TranscriptProcessingProfile) -> String {
        switch profile {
        case .cleanTranscript:
            "Cleaning"
        case .executiveSummary:
            "Summarizing"
        case .todoList:
            "Creating to-do list"
        }
    }

    private var dragHandle: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.draw")
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.hierarchical)

            Text("Drag")
                .font(.callout.weight(.semibold))
        }
        .foregroundStyle(dragHandleForeground)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background {
            Capsule()
                .fill(dragHandleFill)
        }
        .overlay {
            Capsule()
                .strokeBorder(dragHandleStroke, lineWidth: dragHandleStrokeWidth)
        }
        .contentShape(Capsule())
        .scaleEffect(isDragHandleHovered && !isListening && !isAIProcessing ? 1.03 : 1)
        .animation(.easeOut(duration: 0.12), value: isDragHandleHovered)
        .animation(.easeOut(duration: 0.12), value: isDragStarting)
        .onHover { hovering in
            isDragHandleHovered = hovering
            if hovering && !isListening && !isAIProcessing {
                NSCursor.openHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .overlay {
            if !isListening && !isAIProcessing {
                TextDragSourceView(
                    text: model.text,
                    onHoverChanged: { hovering in
                        isDragHandleHovered = hovering
                    },
                    onPressChanged: { pressing in
                        isDragStarting = pressing
                    },
                    onDragStarted: {
                        NSCursor.closedHand.set()
                        isDragStarting = true
                        didRejectLastDrop = false
                        model.onCopy(model.text)
                    },
                    onDragEnded: { operation, targetBundleIdentifier in
                        let dropWasNotConfirmed = operation == [] || targetBundleIdentifier == "com.apple.dt.Xcode"
                        isDragStarting = false
                        if dropWasNotConfirmed {
                            didRejectLastDrop = true
                            model.onDropRejected()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                didRejectLastDrop = false
                            }
                        } else {
                            model.onDismiss()
                        }
                    }
                )
            }
        }
        .help("Drag transcript to another app")
    }

    private var statusColor: Color {
        if isAIProcessing {
            return aiAccent
        }
        if isListening {
            return statusAccent
        }
        return statusAccent
    }

    private var statusFill: Color {
        if isAIProcessing {
            return aiAccent.opacity(0.12)
        }
        if isListening {
            return statusAccent.opacity(0.14)
        }
        return statusAccent.opacity(0.12)
    }

    private var headerTitle: String {
        if let processingProfile = model.processingProfile {
            return processingTitle(for: processingProfile)
        }
        return isListening ? "Listening" : "Review"
    }

    private var headerSubtitle: String {
        if isAIProcessing {
            return "On-device processing"
        }
        if isListening {
            return "Live transcript"
        }
        return "Copied to clipboard"
    }

    private var editorStrokeColor: Color {
        if isAIProcessing {
            return aiAccent.opacity(0.42)
        }
        if isEditorFocused {
            return Color.primary.opacity(0.28)
        }
        return Color.primary.opacity(0.12)
    }

}

private struct CursorHeaderStatusIcon: View {
    let isListening: Bool
    let isProcessing: Bool
    let audioLevelModel: AudioLevelModel
    let accent: Color
    let processingAccent: Color

    var body: some View {
        if isProcessing {
            ProgressView()
                .controlSize(.small)
                .tint(processingAccent)
        } else if isListening {
            LevelWaveformView(level: audioLevelModel.level, color: accent)
                .frame(width: 21, height: 16)
        } else {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accent)
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
    let onDragEnded: (NSDragOperation, String?) -> Void

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
    var onDragEnded: (NSDragOperation, String?) -> Void
    private var hasStartedDrag = false
    private var trackingArea: NSTrackingArea?

    init(
        text: String,
        onHoverChanged: @escaping (Bool) -> Void,
        onPressChanged: @escaping (Bool) -> Void,
        onDragStarted: @escaping () -> Void,
        onDragEnded: @escaping (NSDragOperation, String?) -> Void
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

        let draggingItem = NSDraggingItem(pasteboardWriter: text as NSString)
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
        let targetBundleIdentifier = Self.targetBundleIdentifier(at: screenPoint)
        hasStartedDrag = false
        onPressChanged(false)
        onDragEnded(operation, targetBundleIdentifier)
    }

    private static func targetBundleIdentifier(at screenPoint: NSPoint) -> String? {
        let point = quartzPoint(from: screenPoint)
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let ownProcessIdentifier = NSRunningApplication.current.processIdentifier
        for window in windows {
            guard
                let ownerProcessIdentifier = window[kCGWindowOwnerPID as String] as? pid_t,
                ownerProcessIdentifier != ownProcessIdentifier,
                let layer = window[kCGWindowLayer as String] as? Int,
                layer == 0,
                let boundsDictionary = window[kCGWindowBounds as String] as? [String: Any],
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary),
                bounds.contains(point),
                let application = NSRunningApplication(processIdentifier: ownerProcessIdentifier)
            else { continue }

            return application.bundleIdentifier
        }
        return nil
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
