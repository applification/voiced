import AppKit
import ServiceManagement
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case models
    case vocabulary
    case ai
    case privacy

    var id: Self { self }

    var label: String {
        switch self {
        case .general: "General"
        case .models: "Models"
        case .vocabulary: "Vocabulary"
        case .ai: "AI"
        case .privacy: "Privacy"
        }
    }
}

@Observable
final class SettingsNavigation {
    var selectedSection: SettingsSection = .general
}

struct SettingsView: View {
    var settings: SettingsStore
    var navigation: SettingsNavigation
    @State private var launchAtLoginError: String?
    @State private var modelManagementError: String?
    @State private var modelStatusRevision = 0
    @State private var downloadingModel: TranscriptionModel?
    @State private var modelProgress: ModelLoadProgress?

    init(settings: SettingsStore, navigation: SettingsNavigation = SettingsNavigation()) {
        self.settings = settings
        self.navigation = navigation
    }

    var body: some View {
        VStack(spacing: 16) {
            settingsHeader

            SettingsSegmentedControl(selection: Bindable(navigation).selectedSection)

            Group {
                switch navigation.selectedSection {
                case .general:
                    centeredSettingsContent {
                        generalSettings
                    }
                case .models:
                    centeredSettingsContent {
                        modelSettings
                    }
                case .vocabulary:
                    centeredSettingsContent { VocabularySettingsView(settings: settings) }
                case .ai:
                    centeredSettingsContent {
                        ScrollView { aiSettings }
                    }
                case .privacy:
                    centeredSettingsContent {
                        privacySettings
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 410, maxHeight: 410, alignment: .topLeading)

            settingsFooter
        }
        .padding(24)
        .frame(width: 560, height: 590)
        .onAppear {
            ModelStatusCache.refresh(settings.transcriptionModel)
        }
        .onChange(of: settings.transcriptionModel) {
            ModelStatusCache.refresh(settings.transcriptionModel)
            modelStatusRevision += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .voicedModelProgressChanged)) { notification in
            guard let progress = notification.object as? ModelLoadProgress else { return }
            modelProgress = progress
            if progress.phase == "Loaded" { downloadingModel = nil }
        }
        .onReceive(NotificationCenter.default.publisher(for: .voicedModelStatusChanged)) { notification in
            if let downloadingModel,
               let changedModel = notification.object as? TranscriptionModel,
               changedModel == downloadingModel {
                self.downloadingModel = nil
            }
            modelStatusRevision += 1
        }
    }

    private var settingsHeader: some View {
        HStack(spacing: 12) {
            Image("VoicedHeaderIcon")
                .resizable()
                .interpolation(.high)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 1) {
                Text("Voiced")
                    .font(.title3.weight(.semibold))
                Text("Private dictation for macOS")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

        }
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .center)
    }

    private var settingsFooter: some View {
        HStack(alignment: .center, spacing: 10) {
            Link(destination: URL(string: "https://applification.net")!) {
                HStack(spacing: 6) {
                    Text("Tuned by")
                        .foregroundStyle(.secondary)
                    ApplificationMark()
                        .frame(width: 36, height: 17)
                    Text("Applification")
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Text(appVersionText)
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, minHeight: 18)
    }

    private func centeredSettingsContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack {
            Spacer(minLength: 0)
            content()
                .frame(width: 420, alignment: .topLeading)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 14) {
                GridRow {
                    Text("Dictate and insert")
                        .foregroundStyle(.secondary)
                    Text("Command + Shift + Space")
                }

                GridRow {
                    Text("Save capture")
                        .foregroundStyle(.secondary)
                    Text("Command + Option + Shift + Space")
                }

                GridRow {
                    Text("Startup")
                        .foregroundStyle(.secondary)
                    Toggle("Launch at login", isOn: launchAtLoginBinding)
                }

                GridRow {
                    Text("Activation sound")
                        .foregroundStyle(.secondary)
                    Picker("Activation sound", selection: Bindable(settings).activationSound) {
                        ForEach(SoundCue.allCases) { cue in
                            Text(cue.label).tag(cue)
                        }
                    }
                    .labelsHidden()
                }

                GridRow {
                    Text("Deactivation sound")
                        .foregroundStyle(.secondary)
                    Picker("Deactivation sound", selection: Bindable(settings).deactivationSound) {
                        ForEach(SoundCue.allCases) { cue in
                            Text(cue.label).tag(cue)
                        }
                    }
                    .labelsHidden()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Picker("Live dictation", selection: Bindable(settings).dictationMode) {
                    ForEach(DictationMode.allCases) { Text($0.label).tag($0) }
                }
                Text(settings.dictationMode == .preview
                     ? "Watch words appear beside the caret, then insert once when you release."
                     : "Draft into supported text fields. If the field changes or cannot be updated, use the preview and copy the result.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let launchAtLoginError {
                Text(launchAtLoginError)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 10)
    }

    private var modelSettings: some View {
        let modelStatus = ModelStatusCache.status(for: settings.transcriptionModel)
        let isDownloadingSelectedModel = downloadingModel == settings.transcriptionModel

        return VStack(alignment: .leading, spacing: 18) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 14) {
                GridRow {
                    Text("Transcription model")
                        .foregroundStyle(.secondary)
                    Picker("Transcription model", selection: Bindable(settings).transcriptionModel) {
                        ForEach(TranscriptionModel.allCases) { model in
                            Text(model.menuTitle).tag(model)
                        }
                    }
                    .labelsHidden()
                }

                GridRow {
                    Text("Download")
                        .foregroundStyle(.secondary)
                    Text(modelDownloadDetail(modelStatus: modelStatus, isDownloading: isDownloadingSelectedModel))
                }

                GridRow {
                    Text("Status")
                        .foregroundStyle(.secondary)
                    Text(modelStatusText(modelStatus: modelStatus, isDownloading: isDownloadingSelectedModel))
                }
            }

            HStack(spacing: 12) {
                Button(modelDownloadButtonTitle(modelStatus: modelStatus, isDownloading: isDownloadingSelectedModel)) {
                    downloadSelectedModel()
                }
                .disabled(LoadedModelState.isLoaded(settings.transcriptionModel) || isDownloadingSelectedModel)

                Button("Show in Finder") {
                    showModelFolder()
                }
                .disabled(!modelStatus.isDownloaded)

                Button("Delete downloaded model", role: .destructive) {
                    deleteDownloadedModel()
                }
                .disabled(!modelStatus.existsOnDisk)
            }

            if let modelManagementError {
                Text(modelManagementError)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Model attribution")
                    .font(.callout.weight(.semibold))
                Text(settings.transcriptionModel == .parakeetV2
                     ? "NVIDIA Parakeet v2 English, via FluidAudio and Core ML. Runs on Apple Silicon, including M1 Pro. The download includes a small vocabulary model. Parakeet uses FluidAudio’s shared local model folder."
                     : "WhisperKit by Argmax and OpenAI Whisper, converted for Core ML. Both are MIT licensed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Link("FluidAudio", destination: URL(string: "https://github.com/FluidInference/FluidAudio")!)
                    Link("WhisperKit", destination: URL(string: "https://github.com/argmaxinc/argmax-oss-swift")!)
                    Link("OpenAI Whisper", destination: URL(string: "https://github.com/openai/whisper")!)
                }
                .font(.callout)
            }

            Spacer(minLength: 0)
        }
        .id(modelStatusRevision)
        .padding(.top, 10)
    }

    private var aiSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Clean up after dictation", isOn: Bindable(settings).cleanUpAfterDictation)
            Text("Remove fillers before inserting or saving. The original transcript stays available in the shelf. If local AI is unavailable, use the raw text.")
                .font(.caption).foregroundStyle(.secondary)

            Text("In the shelf, use Refine to preview a cleaned transcript, summary, or to-do list before applying it.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(TranscriptProcessingProfile.allCases) { profile in
                    TranscriptProcessingInfoRow(profile: profile)
                }
            }

            Divider()

            Text("Uses Apple Intelligence on device when available. If the model is not ready, unsupported, or unavailable, Voiced keeps the raw transcript.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.top, 10)
    }

    private var privacySettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Capture permissions")
                    .font(.callout.weight(.semibold))
                HStack {
                    permissionStatusLabel(
                        "Microphone",
                        granted: AppServices.permissions.microphoneAuthorized
                    )
                    Spacer()
                    Button("Open Settings") {
                        Task { await AppServices.permissions.requestOrOpenMicrophone() }
                    }
                }
                HStack {
                    permissionStatusLabel(
                        "Accessibility",
                        granted: AppServices.permissions.accessibilityAuthorized
                    )
                    Spacer()
                    Button("Open Settings") {
                        AppServices.permissions.openAccessibilitySettings()
                    }
                }
                HStack {
                    permissionStatusLabel(
                        "Input Monitoring",
                        granted: AppServices.permissions.inputMonitoringAuthorized
                    )
                    Spacer()
                    Button("Open Settings") {
                        AppServices.permissions.openInputMonitoringSettings()
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("Local by design", systemImage: "lock.shield")
                    .font(.callout.weight(.semibold))
                Text("Captures and transcription stay on this Mac. Voiced has no account, telemetry, cloud storage, or analytics.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.callout)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Local capture file")
                    .font(.callout.weight(.semibold))
                Text("The shelf is saved as readable JSON at ~/Library/Application Support/Voiced/Captures.json.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.callout)

            VStack(alignment: .leading, spacing: 8) {
                Text("Network access")
                    .font(.callout.weight(.semibold))
                Text("Used only when you explicitly download a local speech model. Captures are never uploaded.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.callout)

            Spacer(minLength: 0)
        }
        .padding(.top, 10)
        .onAppear { AppServices.permissions.refresh() }
    }

    private func permissionStatusLabel(_ title: String, granted: Bool) -> some View {
        Label(
            granted ? "\(title) ready" : "\(title) needed",
            systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
        )
        .font(.callout)
        .foregroundStyle(granted ? Color.green : Color.orange)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding {
            settings.launchAtLogin
        } set: { enabled in
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                settings.launchAtLogin = enabled
                launchAtLoginError = nil
            } catch {
                launchAtLoginError = error.localizedDescription
            }
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version?.isEmpty == false ? version : nil, build?.isEmpty == false ? build : nil) {
        case let (.some(version), .some(build)):
            return "Version \(version) (\(build))"
        case let (.some(version), nil):
            return "Version \(version)"
        case let (nil, .some(build)):
            return "Build \(build)"
        case (nil, nil):
            return "Version unavailable"
        }
    }

    private func showModelFolder() {
        let modelStore = ModelStore(model: settings.transcriptionModel)
        guard ModelStatusCache.status(for: settings.transcriptionModel).isDownloaded else { return }
        NSWorkspace.shared.activateFileViewerSelecting([modelStore.localModelURL])
    }

    private func downloadSelectedModel() {
        downloadingModel = settings.transcriptionModel
        if !settings.modelDownloadsApproved {
            settings.modelDownloadsApproved = true
            NotificationCenter.default.post(name: .voicedModelApprovalChanged, object: nil)
        }
        NotificationCenter.default.post(name: .voicedModelDownloadRequested, object: settings.transcriptionModel)
    }

    private func modelDownloadButtonTitle(modelStatus: ModelStatus, isDownloading: Bool) -> String {
        if LoadedModelState.isLoaded(settings.transcriptionModel) { return "Loaded" }
        if isDownloading { return "Preparing…" }
        return modelStatus.isDownloaded ? "Load model" : "Download now"
    }

    private func modelDownloadDetail(modelStatus: ModelStatus, isDownloading: Bool) -> String {
        if isDownloading {
            return "Downloading..."
        }
        return modelStatus.formattedSize
    }

    private func modelStatusText(modelStatus: ModelStatus, isDownloading: Bool) -> String {
        if LoadedModelState.isLoaded(settings.transcriptionModel) { return "Loaded · Ready to dictate" }
        if let modelProgress, modelProgress.model == settings.transcriptionModel, isDownloading {
            return modelProgress.phase
        }
        if modelStatus.isDownloaded {
            return "Downloaded"
        }
        if isDownloading {
            return "Downloading..."
        }
        return "Not downloaded"
    }

    private func deleteDownloadedModel() {
        let alert = NSAlert()
        alert.messageText = "Delete downloaded speech model?"
        alert.informativeText = settings.transcriptionModel == .parakeetV2
            ? "This removes the speech model from FluidAudio’s shared local folder. Other apps using it may need to download it again. The vocabulary model remains cached."
            : "Voiced will need to download this model again before using it after a restart."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try ModelStore(model: settings.transcriptionModel).deleteDownloadedModel()
            ModelStatusCache.setNeedsRefresh(settings.transcriptionModel)
            modelManagementError = nil
            NotificationCenter.default.post(name: .voicedModelStatusChanged, object: settings.transcriptionModel)
        } catch {
            modelManagementError = error.localizedDescription
        }
    }
}

private struct TranscriptProcessingInfoRow: View {
    let profile: TranscriptProcessingProfile

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: profile.settingsSymbolName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.label)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(profile.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.58))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private extension TranscriptProcessingProfile {
    var settingsSymbolName: String {
        switch self {
        case .cleanTranscript:
            "wand.and.sparkles"
        case .executiveSummary:
            "text.badge.checkmark"
        case .todoList:
            "checklist"
        }
    }
}

private struct SettingsSegmentedControl: View {
    @Binding var selection: SettingsSection

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    Text(section.label)
                        .lineLimit(1)
                        .font(.callout.weight(selection == section ? .semibold : .regular))
                        .foregroundStyle(selection == section ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.label)
                .background {
                    if selection == section {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                            .padding(2)
                    }
                }

                if section != SettingsSection.allCases.last {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(width: 1, height: 18)
                        .opacity(selection == section ? 0 : 1)
                }
            }
        }
        .padding(1)
        .frame(width: 420, height: 34)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.8), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Settings section")
    }
}

private struct ApplificationMark: View {
    var body: some View {
        Image("ApplificationMark")
            .resizable()
            .scaledToFit()
    }
}
