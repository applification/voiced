import AppKit
import AVFoundation
import SwiftUI

@MainActor
enum IntroOnboardingPresenter {
    static func presentIfNeeded(settings: SettingsStore, onFinish: @escaping () -> Void) -> NSWindow? {
        guard isSetupRequired(settings: settings) else { return nil }
        return present(settings: settings, mode: .firstRun) {
            settings.hasSeenIntroOnboarding = true
            onFinish()
        }
    }

    static func isSetupRequired(settings: SettingsStore) -> Bool {
        !settings.hasSeenIntroOnboarding
            || AVCaptureDevice.authorizationStatus(for: .audio) != .authorized
            || !ModelStore(model: settings.transcriptionModel).isDownloaded
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
        window.setContentSize(NSSize(width: 680, height: 500))
        window.minSize = NSSize(width: 680, height: 500)
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
    @State private var modelProgress: ModelLoadProgress?
    @State private var downloadingModel: TranscriptionModel?
    @State private var preparedModels: Set<TranscriptionModel> = []
    @State private var selectedModel = TranscriptionModel.tiny

    private var canStart: Bool {
        isSelectedModelPrepared && microphoneStatus == .authorized
    }

    private var canFinish: Bool {
        mode == .setupGuide || canStart
    }

    private var isSelectedModelDownloaded: Bool {
        ModelStore(model: selectedModel).isDownloaded
    }

    private var isSelectedModelPrepared: Bool {
        preparedModels.contains(selectedModel)
    }

    private var modelStatusColor: Color {
        isSelectedModelPrepared ? .green : .secondary
    }

    private var microphoneStatusColor: Color {
        microphoneStatus == .authorized ? .green : .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            modelSection
            Divider()
            microphoneSection
            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 18)
        .frame(width: 680, height: 500, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.18))
        .onAppear {
            refreshStatuses()
            selectedModel = settings.transcriptionModel
        }
        .onReceive(NotificationCenter.default.publisher(for: .voicedModelProgressChanged)) { notification in
            guard let progress = notification.object as? ModelLoadProgress else { return }
            if progress.phase == "Loaded" {
                preparedModels.insert(progress.model)
            }
            guard progress.model == downloadingModel else { return }
            modelProgress = progress
            if progress.phase == "Loaded" {
                downloadingModel = nil
                modelProgress = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .voicedModelStatusChanged)) { notification in
            guard let changedModel = notification.object as? TranscriptionModel else { return }
            reconcileModelState(afterStatusChangeFor: changedModel)
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
        HStack(spacing: 14) {
            Image("VoicedHeaderIcon")
                .resizable()
                .interpolation(.high)
                .frame(width: 40, height: 40)
                .padding(7)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.46))
                }

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

    private var modelSection: some View {
        setupSection(
            symbolName: "brain.head.profile",
            title: "Speech model",
            status: modelStatusText,
            statusColor: modelStatusColor,
            detail: "Choose a local model. Download starts only when you ask for it."
        ) {
            modelChoiceSection
        }
    }

    private var microphoneSection: some View {
        setupSection(
            symbolName: "mic.fill",
            title: "Microphone",
            status: microphoneStatusText,
            statusColor: microphoneStatusColor,
            detail: "Required while push-to-talk is active."
        ) {
            microphoneAction
        }
    }

    private func setupSection<Actions: View>(
        symbolName: String,
        title: String,
        status: String,
        statusColor: Color,
        detail: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbolName)
                .font(.system(size: 17, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.48))
                }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                    Spacer()
                    statusBadge(status, color: statusColor)
                }

                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                actions()
            }
        }
    }

    private var modelChoiceSection: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 0), spacing: 10),
                GridItem(.flexible(minimum: 0), spacing: 10)
            ],
            spacing: 10
        ) {
            ForEach(TranscriptionModel.allCases) { model in
                modelChoiceCard(model)
            }
        }
        .frame(minHeight: 134, alignment: .top)
    }

    private func modelChoiceCard(_ model: TranscriptionModel) -> some View {
        let isSelected = selectedModel == model
        let isDownloaded = ModelStore(model: model).isDownloaded
        let isPrepared = preparedModels.contains(model)
        let isActiveDownload = downloadingModel == model
        let tint = model.tintColor

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: model.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(tint.opacity(0.12))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(model.label)
                            .font(.callout.weight(.semibold))
                        if !isDownloaded {
                            Text("(\(model.downloadSizeText))")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(model.onboardingDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 6)

                modelCardAccessory(
                    model: model,
                    isSelected: isSelected,
                    isDownloaded: isDownloaded,
                    isPrepared: isPrepared,
                    isActiveDownload: isActiveDownload
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color(nsColor: .controlAccentColor).opacity(0.08) : Color(nsColor: .controlBackgroundColor).opacity(0.34))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? Color(nsColor: .controlAccentColor).opacity(0.34) : Color.primary.opacity(0.09), lineWidth: isSelected ? 1 : 0.8)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    @ViewBuilder
    private func modelCardAccessory(
        model: TranscriptionModel,
        isSelected: Bool,
        isDownloaded: Bool,
        isPrepared: Bool,
        isActiveDownload: Bool
    ) -> some View {
        if isPrepared {
            Label("Ready", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
                .labelStyle(.titleAndIcon)
        } else if isActiveDownload {
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
        } else if isSelected && downloadingModel == nil {
            Button(isDownloaded ? "Load Model" : "Download") {
                prepareSelectedModelIfNeeded()
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .controlSize(.small)
        } else if isSelected {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(model.tintColor.opacity(0.85))
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
            .buttonStyle(.bordered)
            .controlSize(.regular)
        case .denied, .restricted:
            Button("Open Microphone Settings") {
                openPrivacyPane("Privacy_Microphone")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        @unknown default:
            Button("Refresh Status") { refreshStatuses() }
                .buttonStyle(.bordered)
                .controlSize(.regular)
        }
    }

    private var footer: some View {
        HStack(alignment: .center) {
            Text(footerStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button(mode.finishButtonTitle) {
                onFinish()
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(!canFinish)
        }
        .padding(.top, 2)
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(color.opacity(0.12))
            }
    }

    private var footerStatusText: String {
        if canStart {
            return "Setup complete."
        }
        if !isSelectedModelPrepared {
            return isSelectedModelDownloaded ? "Load the selected model to continue." : "Download the selected model to continue."
        }
        if microphoneStatus != .authorized {
            return "Allow microphone access to continue."
        }
        return "Complete the required steps to continue."
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
        isSelectedModelPrepared ? "Ready" : "Needed"
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
        if let downloadingModel,
           ModelStore(model: downloadingModel).isDownloaded,
           modelProgress == nil {
            self.downloadingModel = nil
        }
    }

    private func reconcileModelState(afterStatusChangeFor model: TranscriptionModel) {
        if ModelStore(model: model).isDownloaded,
           modelProgress?.phase == "Loaded" {
            preparedModels.insert(model)
        }
        guard downloadingModel == model else { return }
        if preparedModels.contains(model) || !ModelStore(model: model).isDownloaded {
            downloadingModel = nil
            modelProgress = nil
        }
    }

    private func prepareSelectedModelIfNeeded() {
        settings.transcriptionModel = selectedModel
        guard !isSelectedModelPrepared else { return }
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
