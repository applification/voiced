import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var settings: SettingsStore
    @State private var launchAtLoginError: String?

    var body: some View {
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
                    Text("Last capture")
                        .foregroundStyle(.secondary)
                    Stepper(
                        "Clear after \(settings.copyLastTranscriptClearsAfterMinutes) minutes",
                        value: Bindable(settings).copyLastTranscriptClearsAfterMinutes,
                        in: 10...30,
                        step: 10
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
        .padding(24)
        .frame(width: 520, height: 280)
        .onChange(of: settings.transcriptionModel) {
            NotificationCenter.default.post(name: .voicedModelApprovalChanged, object: nil)
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
}
