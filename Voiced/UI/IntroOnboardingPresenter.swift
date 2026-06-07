import AppKit
import AVFoundation
@preconcurrency import ApplicationServices
import SwiftUI

@MainActor
enum IntroOnboardingPresenter {
    static func presentIfNeeded(settings: SettingsStore, onFinish: @escaping () -> Void) -> NSWindow? {
        guard !settings.hasSeenIntroOnboarding else { return nil }
        return present(settings: settings) {
            settings.hasSeenIntroOnboarding = true
            onFinish()
        }
    }

    static func present(settings: SettingsStore, onFinish: @escaping () -> Void = {}) -> NSWindow {
        let hostingController = NSHostingController(
            rootView: IntroOnboardingView(settings: settings, onFinish: onFinish)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to Voiced"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 640, height: 540))
        window.minSize = NSSize(width: 640, height: 540)
        window.isReleasedWhenClosed = false
        hostingController.rootView = IntroOnboardingView(settings: settings, window: window, onFinish: onFinish)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return window
    }
}

private struct IntroOnboardingView: View {
    var settings: SettingsStore
    weak var window: NSWindow?
    var onFinish: () -> Void

    @State private var microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var accessibilityTrusted = AXIsProcessTrustedWithOptions(nil)
    @State private var showingAutoPasteHelp = false
    @State private var showingClipboardHelp = false

    private var canStart: Bool {
        microphoneStatus == .authorized && (settings.outputMode == .copyOnly || accessibilityTrusted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            VStack(alignment: .leading, spacing: 14) {
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

                outputChoiceSection
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()

                Button("Start Using Voiced") {
                    onFinish()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canStart)
            }
        }
        .padding(24)
        .frame(width: 640, height: 540, alignment: .topLeading)
        .onAppear { refreshStatuses() }
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
                Text("Set up Voiced")
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
            Text("Choose how transcripts appear")
                .font(.callout.weight(.semibold))

            HStack(alignment: .top, spacing: 12) {
                outputChoiceCard(
                    title: "Auto Paste",
                    symbolName: "text.insert",
                    isSelected: settings.outputMode == .clipboardPaste,
                    isReady: accessibilityTrusted,
                    status: accessibilityTrusted ? "Ready" : "Optional permission",
                    statusColor: accessibilityTrusted ? .green : .orange,
                    detail: "Paste directly into the app you are using.",
                    helpTitle: "Auto Paste",
                    helpText: "Auto Paste briefly places the transcript on the clipboard, sends \u{2318}V to the app you were using, then restores your previous clipboard when possible. macOS requires Accessibility permission before any app can send that paste command on your behalf.",
                    isShowingHelp: $showingAutoPasteHelp
                ) {
                    settings.outputMode = .clipboardPaste
                    refreshStatuses()
                } actions: {
                    if settings.outputMode == .clipboardPaste && !accessibilityTrusted {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add Voiced in Accessibility:")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 5) {
                                instructionStep("1") {
                                    Button("Open Accessibility Settings") {
                                        requestAccessibilityPrompt()
                                        openPrivacyPane("Privacy_Accessibility")
                                    }
                                }
                                instructionStep("2", "Click +")
                                instructionStep("3", "Open the Applications folder")
                                instructionStep("4") {
                                    HStack(alignment: .center, spacing: 4) {
                                        Text("Select")
                                        Image("VoicedHeaderIcon")
                                            .resizable()
                                            .interpolation(.high)
                                            .frame(width: 14, height: 14)
                                        Text("Voiced, then enable it in the list")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                instructionStep("5", "Return here to proceed")
                            }
                        }
                    }
                }

                outputChoiceCard(
                    title: "Clipboard Only",
                    symbolName: "doc.on.clipboard",
                    isSelected: settings.outputMode == .copyOnly,
                    isReady: true,
                    status: "No extra permission",
                    statusColor: .green,
                    detail: "Copy transcripts. Paste when you are ready.",
                    helpTitle: "Clipboard Only",
                    helpText: "Clipboard Only stops after copying the transcript. You paste manually, so Voiced does not need permission to control other apps.",
                    isShowingHelp: $showingClipboardHelp
                ) {
                    settings.outputMode = .copyOnly
                    refreshStatuses()
                } actions: {
                    EmptyView()
                }
            }
            .frame(height: 232)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private func refreshStatuses() {
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        accessibilityTrusted = AXIsProcessTrustedWithOptions(nil)
    }

    private func bringOnboardingForward(after delay: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            window?.orderFrontRegardless()
        }
    }

    private func requestAccessibilityPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
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
