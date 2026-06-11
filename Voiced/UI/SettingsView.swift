import AppKit
import ServiceManagement
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case models
    case ai
    case privacy

    var id: Self { self }

    var label: String {
        switch self {
        case .general: "General"
        case .models: "Models"
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
                case .ai:
                    centeredSettingsContent {
                        aiSettings
                    }
                case .privacy:
                    centeredSettingsContent {
                        privacySettings
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 340, maxHeight: 340, alignment: .topLeading)

            settingsFooter
        }
        .padding(24)
        .frame(width: 560, height: 520)
        .onAppear {
            ModelStatusCache.refresh(settings.transcriptionModel)
        }
        .onChange(of: settings.transcriptionModel) {
            ModelStatusCache.refresh(settings.transcriptionModel)
            modelStatusRevision += 1
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
                    Text("Push-to-talk")
                        .foregroundStyle(.secondary)
                    Picker("Push-to-talk", selection: Bindable(settings).pushToTalkHotkey) {
                        ForEach(PushToTalkHotkey.allCases) { hotkey in
                            Text(hotkey.label).tag(hotkey)
                        }
                    }
                    .labelsHidden()
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
                .disabled(modelStatus.isDownloaded || isDownloadingSelectedModel)

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
                Text("Voiced uses WhisperKit by Argmax and OpenAI Whisper models converted for Core ML. WhisperKit is MIT licensed. OpenAI Whisper is MIT licensed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
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
            Text("After dictation, use these actions in the review panel to reshape the captured text before pasting.")
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
            Toggle("Share basic usage and crash diagnostics", isOn: diagnosticsBinding)

            Text("Helps us understand whether Voiced is working. Never sends audio, transcripts, clipboard contents, screen recordings, file paths, or the apps you dictate into.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Included")
                    .font(.callout.weight(.semibold))
                Text("App opens, app version, macOS version, anonymous install activity, recording starts and cancellations, transcription success or failure, selected model, coarse duration buckets, and broad error categories.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.callout)

            VStack(alignment: .leading, spacing: 8) {
                Text("Not included")
                    .font(.callout.weight(.semibold))
                Text("Audio, transcript text, clipboard contents, screenshots, session replay, file names, file paths, window titles, and target application names.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.callout)

            Spacer(minLength: 0)
        }
        .padding(.top, 10)
    }

    private var diagnosticsBinding: Binding<Bool> {
        Binding {
            settings.basicDiagnosticsEnabled
        } set: { enabled in
            settings.basicDiagnosticsEnabled = enabled
            AppServices.telemetry.setBasicDiagnosticsEnabled(enabled)
        }
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
        if modelStatus.isDownloaded {
            return "Downloaded"
        }
        if isDownloading {
            return "Downloading..."
        }
        return "Download now"
    }

    private func modelDownloadDetail(modelStatus: ModelStatus, isDownloading: Bool) -> String {
        if isDownloading {
            return "Downloading..."
        }
        return modelStatus.formattedSize
    }

    private func modelStatusText(modelStatus: ModelStatus, isDownloading: Bool) -> String {
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
        alert.messageText = "Delete downloaded Whisper model?"
        alert.informativeText = "Voiced will ask for approval before downloading the model again."
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
                        .font(.callout.weight(selection == section ? .semibold : .regular))
                        .foregroundStyle(selection == section ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
        .frame(width: 300, height: 34)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.8), lineWidth: 1)
        }
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
