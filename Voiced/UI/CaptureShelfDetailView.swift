import SwiftUI

struct CaptureShelfDetailView: View {
    let item: CaptureItem
    let processingAvailability: TranscriptProcessingAvailability
    let onUpdate: (UUID, String) -> Void
    let onMove: (UUID, CaptureStatus) -> Void
    let onCopy: (String) -> Void
    let onInsert: (CaptureItem, String) async -> OutputResult
    let onProcess: (TranscriptProcessingProfile, String) async throws -> String
    let onLoadReminderLists: (Bool) async -> [ReminderListOption]
    let onExportToReminders: (String, String?) async -> ReminderExportResult
    let onRemove: (CaptureItem) -> Void

    @State private var editText: String
    @State private var processingProfile: TranscriptProcessingProfile?
    @State private var processingTask: Task<Void, Never>?
    @State private var reminderLists: [ReminderListOption] = []
    @State private var isLoadingReminderLists = false
    @State private var isExportingToReminders = false
    @State private var actionMessage: String?
    @FocusState private var isEditorFocused: Bool

    init(
        item: CaptureItem,
        processingAvailability: TranscriptProcessingAvailability,
        onUpdate: @escaping (UUID, String) -> Void,
        onMove: @escaping (UUID, CaptureStatus) -> Void,
        onCopy: @escaping (String) -> Void,
        onInsert: @escaping (CaptureItem, String) async -> OutputResult,
        onProcess: @escaping (TranscriptProcessingProfile, String) async throws -> String,
        onLoadReminderLists: @escaping (Bool) async -> [ReminderListOption],
        onExportToReminders: @escaping (String, String?) async -> ReminderExportResult,
        onRemove: @escaping (CaptureItem) -> Void
    ) {
        self.item = item
        self.processingAvailability = processingAvailability
        self.onUpdate = onUpdate
        self.onMove = onMove
        self.onCopy = onCopy
        self.onInsert = onInsert
        self.onProcess = onProcess
        self.onLoadReminderLists = onLoadReminderLists
        self.onExportToReminders = onExportToReminders
        self.onRemove = onRemove
        _editText = State(initialValue: item.text)
    }

    private var normalizedText: String {
        editText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var reminderTaskCount: Int {
        ReminderChecklistParser.taskCount(in: editText)
    }

    private var isBusy: Bool {
        processingProfile != nil || isExportingToReminders
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            TextEditor(text: $editText)
                .font(.body)
                .lineSpacing(3)
                .textEditorStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(12)
                .focused($isEditorFocused)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .voicedGlassSurface(cornerRadius: 14, interactive: true)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isEditorFocused
                                ? VoicedShelfStyle.signalMint.opacity(0.72)
                                : Color.primary.opacity(0.08),
                            lineWidth: isEditorFocused ? 1.5 : 0.5
                        )
                }
                .onChange(of: editText) { _, newValue in
                    guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    onUpdate(item.id, newValue)
                    actionMessage = nil
                }

            processingActions

            if let actionMessage {
                Label(actionMessage, systemImage: messageSymbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else if let unavailableMessage = processingAvailability.unavailableMessage {
                Label(unavailableMessage, systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            primaryActions
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: reminderTaskCount) {
            guard reminderTaskCount > 0 else {
                reminderLists = []
                return
            }
            reminderLists = await onLoadReminderLists(false)
        }
        .onDisappear {
            processingTask?.cancel()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: item.source.symbolName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(VoicedShelfStyle.signalMint)
                .frame(width: 30, height: 30)
                .voicedGlassSurface(cornerRadius: 9, tint: VoicedShelfStyle.signalMint.opacity(0.08))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.source.label)
                    .font(.headline)
                Text(metadata)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Status", selection: Binding(
                get: { item.status },
                set: { onMove(item.id, $0) }
            )) {
                ForEach(CaptureStatus.allCases) { status in
                    Text(status.label).tag(status)
                }
            }
            .labelsHidden()
            .frame(width: 105)
            .controlSize(.small)
        }
    }

    private var processingActions: some View {
        HStack(spacing: 7) {
            processingButton(.cleanTranscript, title: "Clean", symbol: "wand.and.sparkles")
            processingButton(.executiveSummary, title: "Summarize", symbol: "text.alignleft")
            processingButton(.todoList, title: "To-do", symbol: "checklist")

            if reminderTaskCount > 0 {
                remindersMenu
            }

            Spacer(minLength: 0)
        }
        .controlSize(.small)
        .voicedGlassGroup(spacing: 7)
    }

    private func processingButton(
        _ profile: TranscriptProcessingProfile,
        title: String,
        symbol: String
    ) -> some View {
        Button {
            process(profile)
        } label: {
            if processingProfile == profile {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 52)
            } else {
                Label(title, systemImage: symbol)
            }
        }
        .voicedGlassButton()
        .disabled(isBusy || !processingAvailability.isAvailable || normalizedText.isEmpty)
        .help(processingAvailability.unavailableMessage ?? profile.detail)
    }

    private var remindersMenu: some View {
        Menu {
            Button("Default List") {
                exportToReminders(listID: nil)
            }

            Divider()
            if reminderLists.isEmpty {
                Button(isLoadingReminderLists ? "Loading Lists…" : "Choose List…") {
                    loadReminderListsRequestingAccess()
                }
                .disabled(isLoadingReminderLists)
            } else {
                ForEach(reminderLists) { list in
                    Button(list.isDefault ? "\(list.title) (Default)" : list.title) {
                        exportToReminders(listID: list.id)
                    }
                }
            }
        } label: {
            Label(
                isExportingToReminders ? "Adding…" : "Reminders",
                systemImage: isExportingToReminders ? "hourglass" : "list.bullet.clipboard"
            )
        }
        .menuStyle(.borderlessButton)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .voicedGlassSurface(cornerRadius: 8, interactive: true)
        .disabled(isBusy)
        .help("Add \(reminderTaskCount) checklist \(reminderTaskCount == 1 ? "item" : "items") to Reminders")
    }

    private var primaryActions: some View {
        HStack(spacing: 8) {
            Button("Insert", systemImage: "arrow.turn.down.left") {
                insertCapture()
            }
            .voicedGlassButton(prominent: true, tint: VoicedShelfStyle.signalMint)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(normalizedText.isEmpty || isBusy)

            Button("Copy", systemImage: "doc.on.doc") {
                onCopy(normalizedText)
                actionMessage = "Copied to clipboard"
            }
            .voicedGlassButton()
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(normalizedText.isEmpty)

            CaptureTextDragHandle(text: normalizedText)
                .disabled(normalizedText.isEmpty || isBusy)

            Spacer()

            Button("Remove", systemImage: "trash", role: .destructive) {
                onRemove(item)
            }
            .voicedGlassButton()
        }
        .controlSize(.regular)
        .voicedGlassGroup(spacing: 8)
    }

    private var metadata: String {
        var parts = [item.updatedAt.formatted(date: .abbreviated, time: .shortened)]
        if let appName = item.sourceApplication?.name { parts.append(appName) }
        return parts.joined(separator: " · ")
    }

    private var messageSymbol: String {
        if actionMessage?.hasPrefix("Could") == true || actionMessage?.hasSuffix("failed") == true {
            return "exclamationmark.triangle"
        }
        return "checkmark.circle"
    }

    private func process(_ profile: TranscriptProcessingProfile) {
        processingTask?.cancel()
        processingProfile = profile
        actionMessage = nil
        let input = normalizedText
        processingTask = Task { @MainActor in
            do {
                let processed = try await onProcess(profile, input)
                try Task.checkCancellation()
                editText = processed
                actionMessage = "\(profile.label) applied"
            } catch is CancellationError {
            } catch {
                actionMessage = "Couldn’t process this capture"
            }
            processingProfile = nil
            processingTask = nil
        }
    }

    private func insertCapture() {
        actionMessage = nil
        Task { @MainActor in
            let result = await onInsert(item, normalizedText)
            actionMessage = switch result {
            case .inserted: "Inserted and moved to Done"
            case .accessibilityRequired: "Accessibility permission is required"
            case .copied: "Copied to clipboard"
            case .failed: "Insertion failed"
            }
        }
    }

    private func loadReminderListsRequestingAccess() {
        guard !isLoadingReminderLists else { return }
        isLoadingReminderLists = true
        Task { @MainActor in
            reminderLists = await onLoadReminderLists(true)
            isLoadingReminderLists = false
            if reminderLists.isEmpty {
                actionMessage = "Couldn’t load Reminders lists"
            }
        }
    }

    private func exportToReminders(listID: String?) {
        guard !isExportingToReminders else { return }
        isExportingToReminders = true
        actionMessage = nil
        Task { @MainActor in
            switch await onExportToReminders(editText, listID) {
            case .success(let count):
                actionMessage = count == 1 ? "Added 1 reminder" : "Added \(count) reminders"
            case .failure(let message):
                actionMessage = message
            }
            isExportingToReminders = false
            if !reminderLists.isEmpty {
                reminderLists = await onLoadReminderLists(false)
            }
        }
    }
}

private struct CaptureTextDragHandle: View {
    let text: String

    var body: some View {
        Label("Drag", systemImage: "hand.draw")
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .voicedGlassSurface(cornerRadius: 8, interactive: true)
            .draggable(text)
            .help("Drag capture text to another app")
            .accessibilityLabel("Drag capture text")
    }
}
