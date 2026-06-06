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

    init(settings: SettingsStore, navigation: SettingsNavigation = SettingsNavigation()) {
        self.settings = settings
        self.navigation = navigation
    }

    var body: some View {
        TabView(selection: Bindable(navigation).selectedSection) {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsSection.general)

            modelSettings
                .tabItem {
                    Label("Models", systemImage: "brain.head.profile")
                }
                .tag(SettingsSection.models)
        }
        .padding(24)
        .frame(width: 560, height: 360)
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

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 14) {
                GridRow {
                    Text("Output mode")
                        .foregroundStyle(.secondary)
                    Picker("Output mode", selection: Bindable(settings).outputMode) {
                        ForEach(OutputMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .labelsHidden()
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
