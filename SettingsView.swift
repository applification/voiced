import AppKit
import ServiceManagement
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case models

    var id: Self { self }

    var label: String {
        switch self {
        case .general: "General"
        case .models: "Models"
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
    @State private var showingOutputModeHelp = false

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
                }
            }
            .frame(maxWidth: .infinity, minHeight: 250, maxHeight: 250, alignment: .topLeading)

            settingsFooter
        }
        .padding(24)
        .frame(width: 560, height: 430)
        .onChange(of: settings.transcriptionModel) { modelStatusRevision += 1 }
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
                    Text("Output mode")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Picker("Output mode", selection: Bindable(settings).outputMode) {
                            ForEach(OutputMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .labelsHidden()

                        HelpButton {
                            showingOutputModeHelp.toggle()
                        }
                        .popover(isPresented: $showingOutputModeHelp, arrowEdge: .trailing) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Output mode")
                                    .font(.headline)
                                Text(outputModeSecurityNote)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(width: 260, alignment: .leading)
                            .padding(14)
                        }
                    }
                }

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
                    Text("Last capture")
                        .foregroundStyle(.secondary)
                    Stepper(
                        "Clear after \(settings.copyLastTranscriptClearsAfterMinutes) minute\(settings.copyLastTranscriptClearsAfterMinutes == 1 ? "" : "s")",
                        value: Bindable(settings).copyLastTranscriptClearsAfterMinutes,
                        in: 1...5,
                        step: 1
                    )
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
        let modelStore = ModelStore(model: settings.transcriptionModel)
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
                    Text(modelDownloadDetail(modelStore: modelStore, isDownloading: isDownloadingSelectedModel))
                }

                GridRow {
                    Text("Status")
                        .foregroundStyle(.secondary)
                    Text(modelStatusText(modelStore: modelStore, isDownloading: isDownloadingSelectedModel))
                }
            }

            HStack(spacing: 12) {
                Button(modelDownloadButtonTitle(modelStore: modelStore, isDownloading: isDownloadingSelectedModel)) {
                    downloadSelectedModel()
                }
                .disabled(modelStore.isDownloaded || isDownloadingSelectedModel)

                Button("Show in Finder") {
                    showModelFolder()
                }
                .disabled(!modelStore.isDownloaded)

                Button("Delete downloaded model", role: .destructive) {
                    deleteDownloadedModel()
                }
                .disabled(!modelStore.existsOnDisk)
            }

            if let modelManagementError {
                Text(modelManagementError)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .id(modelStatusRevision)
        .padding(.top, 10)
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

    private var outputModeSecurityNote: String {
        switch settings.outputMode {
        case .clipboardPaste:
            "Paste mode uses Accessibility permission to send Cmd+V to the focused app. Copy-only avoids synthetic keystrokes."
        case .copyOnly:
            "Copy-only leaves the transcript on the clipboard and does not send keystrokes to other apps."
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

        return switch version {
        case let .some(version):
            "Version \(version)"
        default:
            "Version unavailable"
        }
    }

    private func showModelFolder() {
        let modelStore = ModelStore(model: settings.transcriptionModel)
        guard modelStore.isDownloaded else { return }
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

    private func modelDownloadButtonTitle(modelStore: ModelStore, isDownloading: Bool) -> String {
        if modelStore.isDownloaded {
            return "Downloaded"
        }
        if isDownloading {
            return "Downloading..."
        }
        return "Download now"
    }

    private func modelDownloadDetail(modelStore: ModelStore, isDownloading: Bool) -> String {
        if isDownloading {
            return "Downloading..."
        }
        return modelStore.formattedSize
    }

    private func modelStatusText(modelStore: ModelStore, isDownloading: Bool) -> String {
        if modelStore.isDownloaded {
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
            modelManagementError = nil
            NotificationCenter.default.post(name: .voicedModelStatusChanged, object: settings.transcriptionModel)
        } catch {
            modelManagementError = error.localizedDescription
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
        .frame(width: 240, height: 34)
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

private struct HelpButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 13, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 14, height: 14)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .help("Show output mode help")
    }
}
