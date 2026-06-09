import AppKit
import AVFoundation
import SwiftUI

@MainActor
enum IntroOnboardingPresenter {
    static func presentIfNeeded(settings: SettingsStore, onFinish: @escaping () -> Void) -> NSWindow? {
        guard !settings.hasSeenIntroOnboarding else { return nil }
        return present(settings: settings, mode: .firstRun) {
            settings.hasSeenIntroOnboarding = true
            onFinish()
        }
    }

    static func presentSetupGuide(settings: SettingsStore, onFinish: @escaping () -> Void = {}) -> NSWindow {
        present(settings: settings, mode: .setupGuide, onFinish: onFinish)
    }

    private static func present(settings: SettingsStore, mode: IntroOnboardingMode, onFinish: @escaping () -> Void = {}) -> NSWindow {
        let hostingController = NSHostingController(
            rootView: IntroOnboardingView(settings: settings, mode: mode, onFinish: onFinish)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = mode.windowTitle
        window.styleMask = [.titled, .closable]
        if mode == .firstRun {
            window.styleMask.remove(.closable)
        }
        window.setContentSize(NSSize(width: 700, height: 660))
        window.minSize = NSSize(width: 700, height: 660)
        window.isReleasedWhenClosed = false
        hostingController.rootView = IntroOnboardingView(settings: settings, mode: mode, window: window, onFinish: onFinish)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return window
    }
}

private enum IntroOnboardingMode {
    case firstRun
    case setupGuide

    var windowTitle: String {
        switch self {
        case .firstRun: "Welcome to Voiced"
        case .setupGuide: "Voiced Setup Guide"
        }
    }

    var heading: String {
        switch self {
        case .firstRun: "Set up Voiced"
        case .setupGuide: "Review setup"
        }
    }

    var finishButtonTitle: String {
        switch self {
        case .firstRun: "Start Using Voiced"
        case .setupGuide: "Done"
        }
    }
}

private struct IntroOnboardingView: View {
    var settings: SettingsStore
    var mode: IntroOnboardingMode
    weak var window: NSWindow?
    var onFinish: () -> Void

    @State private var microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var showingReviewHelp = false
    @State private var showingClipboardHelp = false
    @State private var modelProgress: ModelLoadProgress?
    @State private var downloadingModel: TranscriptionModel?
    @State private var selectedModel = TranscriptionModel.tiny

    private var canStart: Bool {
        isSelectedModelReady && microphoneStatus == .authorized
    }

    private var canFinish: Bool {
        mode == .setupGuide || canStart
    }

    private var isSelectedModelReady: Bool {
        ModelStore(model: selectedModel).isDownloaded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(alignment: .leading, spacing: 12) {
                setupRow(
                    symbolName: "brain.head.profile",
                    title: "Speech model",
                    status: modelStatusText,
                    statusColor: isSelectedModelReady ? .green : .orange,
                    detail: "Choose a local model. Bigger models take longer to download but can improve accuracy."
                ) {
                    modelChoiceSection
                }

                Divider()

                setupRow(
                    symbolName: "mic.fill",
                    title: "Microphone",
                    status: microphoneStatusText,
                    statusColor: microphoneStatus == .authorized ? .green : .orange,
                    detail: "Required to record while push-to-talk is active."
                ) {
                    microphoneAction
                }

                Divider()

                setupRow(
                    symbolName: "text.bubble.fill",
                    title: "Transcripts",
                    status: transcriptStatusText,
                    statusColor: transcriptStatusColor,
                    detail: "Choose how Voiced delivers each transcript."
                ) {
                    outputChoiceSection
                }
            }

            Spacer(minLength: 4)

            HStack {
                Spacer()

                Button(mode.finishButtonTitle) {
                    onFinish()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canFinish)
            }
        }
        .padding(24)
        .frame(width: 700, height: 660, alignment: .topLeading)
        .onAppear {
            refreshStatuses()
            selectedModel = settings.transcriptionModel
        }
        .onReceive(NotificationCenter.default.publisher(for: .voicedModelProgressChanged)) { notification in
            guard let progress = notification.object as? ModelLoadProgress,
                  progress.model == downloadingModel else { return }
            modelProgress = progress
        }
        .onReceive(NotificationCenter.default.publisher(for: .voicedModelStatusChanged)) { notification in
            let changedModel = notification.object as? TranscriptionModel
            if let changedModel,
               changedModel == downloadingModel,
               ModelStore(model: changedModel).isDownloaded {
                downloadingModel = nil
                modelProgress = nil
            }
            guard changedModel == selectedModel else { return }
            refreshStatuses()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshStatuses()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            guard notification.object as? NSWindow === window else { return }
            refreshStatuses()
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            guard window?.isVisible == true else { return }
            refreshStatuses()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("VoicedHeaderIcon")
                .resizable()
                .interpolation(.high)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(mode.heading)
                    .font(.title3.weight(.semibold))
                Text("Hold \(settings.pushToTalkHotkey.onboardingLabel) to record, then release to transcribe.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func setupRow<Actions: View>(
        symbolName: String,
        title: String,
        status: String,
        statusColor: Color,
        detail: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                    Spacer()
                    Text(status)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(statusColor)
                }

                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                actions()
            }
        }
    }

    private var outputChoiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                outputChoiceCard(
                    title: "Review Bubble",
                    symbolName: "text.bubble",
                    isSelected: settings.outputMode == .review,
                    isReady: true,
                    status: "Ready",
                    statusColor: .green,
                    detail: "Show transcripts near the cursor so you can check, edit, copy, or drag them.",
                    helpTitle: "Review Bubble",
                    helpText: "Review Bubble copies the transcript, then keeps a small editable preview near the cursor. Paste manually with Command-V or drag the text into another app.",
                    isShowingHelp: $showingReviewHelp
                ) {
                    settings.outputMode = .review
                    refreshStatuses()
                } actions: {
                    Text("Copied first. You stay in control of when it goes into another app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                outputChoiceCard(
                    title: "Copy Only",
                    symbolName: "doc.on.clipboard",
                    isSelected: settings.outputMode == .copyOnly,
                    isReady: true,
                    status: "No extra permission",
                    statusColor: .green,
                    detail: "Copy transcripts. Paste when you are ready.",
                    helpTitle: "Copy Only",
                    helpText: "Copy Only stops after copying the transcript. It does not show the review bubble.",
                    isShowingHelp: $showingClipboardHelp
                ) {
                    settings.outputMode = .copyOnly
                    refreshStatuses()
                } actions: {
                    EmptyView()
                }
            }
            .padding(.top, 10)
            .frame(height: 162)
        }
    }

    private var modelChoiceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 8
            ) {
                ForEach(TranscriptionModel.allCases) { model in
                    modelChoiceCard(model)
                }
            }

        }
    }

    private func modelChoiceCard(_ model: TranscriptionModel) -> some View {
        let isSelected = selectedModel == model
        let isDownloaded = ModelStore(model: model).isDownloaded
        let tint = model.tintColor
        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: model.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.label)
                        .font(.callout.weight(.semibold))
                    Text(model.onboardingDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 4)

                if isDownloaded {
                    Label("Ready", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                } else if isSelected && downloadingModel == nil {
                    Button("Download (\(model.downloadSizeText))") {
                        startSelectedModelDownloadIfNeeded()
                    }
                    .font(.caption.weight(.medium))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else if downloadingModel == model {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.65)
                        Text(modelInlineProgressText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                } else if isSelected && downloadingModel != nil {
                    Text("Waiting")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                } else if isSelected {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 16, height: 16)
                }
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
        .background(isSelected ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isSelected ? 1.5 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            guard downloadingModel == nil || downloadingModel == model else {
                selectedModel = model
                return
            }
            selectedModel = model
            settings.transcriptionModel = model
            if downloadingModel == nil {
                modelProgress = nil
            }
        }
    }

    private func outputChoiceCard<Actions: View>(
        title: String,
        symbolName: String,
        isSelected: Bool,
        isReady: Bool,
        status: String,
        statusColor: Color,
        detail: String,
        helpTitle: String,
        helpText: String,
        isShowingHelp: Binding<Bool>,
        select: @escaping () -> Void,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        let selectedColor = Color.accentColor.opacity(0.10)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: symbolName)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text(status)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(statusColor)
                }

                Spacer(minLength: 8)

                HelpPopoverButton(title: helpTitle, text: helpText, isPresented: isShowingHelp)

                if isSelected && isReady {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }

            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            actions()

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 162, maxHeight: .infinity, alignment: .topLeading)
        .background(isSelected ? selectedColor : Color(nsColor: .controlBackgroundColor).opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isSelected ? 1.5 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            select()
        }
    }

    private func instructionStep(_ number: String, _ text: String) -> some View {
        instructionStep(number) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func instructionStep<Content: View>(_ number: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(number)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.accentColor.opacity(0.12)))

            content()
        }
    }

    @ViewBuilder
    private var microphoneAction: some View {
        switch microphoneStatus {
        case .authorized:
            EmptyView()
        case .notDetermined:
            Button("Allow Microphone") {
                AVCaptureDevice.requestAccess(for: .audio) { _ in
                    Task { @MainActor in
                        refreshStatuses()
                        bringOnboardingForward()
                        bringOnboardingForward(after: 0.35)
                        bringOnboardingForward(after: 0.9)
                    }
                }
            }
        case .denied, .restricted:
            Button("Open Microphone Settings") {
                openPrivacyPane("Privacy_Microphone")
            }
        @unknown default:
            Button("Refresh status") { refreshStatuses() }
        }
    }

    private var microphoneStatusText: String {
        switch microphoneStatus {
        case .authorized: "Ready"
        case .notDetermined: "Needed"
        case .denied, .restricted: "Off"
        @unknown default: "Unknown"
        }
    }

    private var modelStatusText: String {
        if isSelectedModelReady {
            return "Ready"
        }
        guard let modelProgress else {
            return downloadingModel != nil ? "Starting" : "Needed"
        }
        if modelProgress.phase == "Downloading" {
            return "\(Int((modelProgress.fractionCompleted * 100).rounded()))%"
        }
        return modelProgress.phase
    }

    private var transcriptStatusText: String {
        "Ready"
    }

    private var transcriptStatusColor: Color {
        .green
    }

    private var modelInlineProgressText: String {
        guard let modelProgress else { return "Starting" }
        if modelProgress.phase == "Downloading" {
            return "\(Int((modelProgress.fractionCompleted * 100).rounded()))%"
        }
        return modelProgress.phase
    }

    private func refreshStatuses() {
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    }

    private func startSelectedModelDownloadIfNeeded() {
        settings.transcriptionModel = selectedModel
        guard !isSelectedModelReady else { return }
        guard downloadingModel == nil else { return }
        downloadingModel = selectedModel
        modelProgress = nil
        if !settings.modelDownloadsApproved {
            settings.modelDownloadsApproved = true
            NotificationCenter.default.post(name: .voicedModelApprovalChanged, object: nil)
        }
        NotificationCenter.default.post(
            name: .voicedModelDownloadRequested,
            object: selectedModel,
            userInfo: ["source": "onboarding"]
        )
    }

    private func bringOnboardingForward(after delay: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            window?.orderFrontRegardless()
        }
    }

    private func openPrivacyPane(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct HelpPopoverButton: View {
    let title: String
    let text: String
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 13, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .help("Show help for \(title)")
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 280, alignment: .leading)
            .padding(14)
        }
    }
}
