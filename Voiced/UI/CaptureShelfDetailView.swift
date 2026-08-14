import SwiftUI

struct CaptureShelfDetailView: View {
    let item: CaptureItem
    let processingAvailability: TranscriptProcessingAvailability
    let onUpdate: (UUID, String) -> Void
    let onMove: (UUID, CaptureStatus) -> Void
    let onCopy: (String) -> Void
    let onProcess: (TranscriptProcessingProfile, String) async throws -> String
    let onLoadReminderLists: (Bool) async -> [ReminderListOption]
    let onExportToReminders: (String, String?) async -> ReminderExportResult
    let onRemove: (CaptureItem) -> Void

    @Environment(\.undoManager) private var undoManager
    @State private var editText: String
    @State private var processingProfile: TranscriptProcessingProfile?
    @State private var processingTask: Task<Void, Never>?
    @State private var refinementPreview: RefinementPreview?
    @State private var previewSelection: RefinementPreviewSelection = .proposed
    @State private var lastAppliedRefinement: AppliedRefinement?
    @State private var reminderLists: [ReminderListOption] = []
    @State private var isLoadingReminderLists = false
    @State private var isExportingToReminders = false
    @State private var actionNotice: CaptureActionNotice?
    @State private var undoTarget = CaptureDetailUndoTarget()
    @FocusState private var isEditorFocused: Bool

    init(
        item: CaptureItem,
        processingAvailability: TranscriptProcessingAvailability,
        onUpdate: @escaping (UUID, String) -> Void,
        onMove: @escaping (UUID, CaptureStatus) -> Void,
        onCopy: @escaping (String) -> Void,
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
        VStack(alignment: .leading, spacing: 14) {
            header
            editorOrPreview
            secondaryActions
            feedback
            Spacer(minLength: 0)
            outputActions
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
        .onChange(of: item.text) { _, newValue in
            guard refinementPreview == nil,
                  newValue != normalizedText else { return }
            editText = newValue
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
            .frame(width: 105)
            .controlSize(.small)
            .accessibilityLabel("Capture status")
        }
    }

    @ViewBuilder
    private var editorOrPreview: some View {
        if let refinementPreview {
            refinementPreviewView(refinementPreview)
        } else {
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
                    guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        actionNotice = .warning("Empty captures aren’t saved")
                        return
                    }
                    onUpdate(item.id, newValue)
                    actionNotice = nil
                    lastAppliedRefinement = nil
                }
                .onChange(of: isEditorFocused) { _, focused in
                    guard !focused, normalizedText.isEmpty else { return }
                    editText = item.text
                    actionNotice = .warning("Restored the last saved text")
                }
                .accessibilityLabel("Capture text")
        }
    }

    private func refinementPreviewView(_ preview: RefinementPreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("Review \(preview.profile.label.lowercased())", systemImage: "sparkles")
                    .font(.callout.weight(.semibold))
                Spacer()
                Picker("Preview text", selection: $previewSelection) {
                    Text("Proposed").tag(RefinementPreviewSelection.proposed)
                    Text("Original").tag(RefinementPreviewSelection.original)
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }

            ScrollView {
                Text(previewSelection == .proposed ? preview.proposedText : preview.originalText)
                    .font(.body)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Color(nsColor: .textBackgroundColor).opacity(0.55),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )

            HStack(spacing: 8) {
                Button("Keep Original") {
                    cancelRefinement()
                }
                .voicedGlassButton()

                Spacer()

                Button("Apply \(preview.profile.label)") {
                    applyRefinement(preview)
                }
                .voicedGlassButton(prominent: true, tint: VoicedShelfStyle.signalMint)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var secondaryActions: some View {
        HStack(spacing: 7) {
            Menu {
                refinementMenuButton(.cleanTranscript, symbol: "wand.and.sparkles")
                refinementMenuButton(.executiveSummary, symbol: "text.alignleft")
                refinementMenuButton(.todoList, symbol: "checklist")
            } label: {
                if let processingProfile {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(processingProfile.label)
                    }
                } else {
                    Label("Refine", systemImage: "sparkles")
                }
            }
            .menuStyle(.borderlessButton)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .voicedGlassSurface(cornerRadius: 8, interactive: true)
            .disabled(isBusy || refinementPreview != nil || !processingAvailability.isAvailable || normalizedText.isEmpty)
            .help(processingAvailability.unavailableMessage ?? "Preview a cleaned transcript, summary, or to-do list")

            if reminderTaskCount > 0, refinementPreview == nil {
                remindersMenu
            }

            Spacer(minLength: 0)
        }
        .controlSize(.small)
    }

    private func refinementMenuButton(_ profile: TranscriptProcessingProfile, symbol: String) -> some View {
        Button {
            process(profile)
        } label: {
            Label(profile.label, systemImage: symbol)
        }
        .disabled(isBusy || !processingAvailability.isAvailable || normalizedText.isEmpty)
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

    @ViewBuilder
    private var feedback: some View {
        if let actionNotice {
            HStack(spacing: 7) {
                Label(actionNotice.message, systemImage: actionNotice.symbolName)
                    .font(.caption)
                    .foregroundStyle(actionNotice.isWarning ? Color.orange : Color.secondary)
                    .lineLimit(2)
                if lastAppliedRefinement != nil {
                    Button("Undo") { undoLastRefinement() }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            }
        } else if let unavailableMessage = processingAvailability.unavailableMessage {
            Label(unavailableMessage, systemImage: "sparkles")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var outputActions: some View {
        HStack(spacing: 8) {
            Button("Copy", systemImage: "doc.on.doc") {
                onCopy(normalizedText)
                actionNotice = .success("Copied to clipboard")
            }
            .voicedGlassButton(prominent: true, tint: VoicedShelfStyle.signalMint)
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(normalizedText.isEmpty || refinementPreview != nil)

            CaptureTextDragHandle(text: normalizedText)
                .disabled(normalizedText.isEmpty || isBusy || refinementPreview != nil)

            Spacer()

            Button("Remove", systemImage: "trash", role: .destructive) {
                onRemove(item)
            }
            .voicedGlassButton()
            .disabled(isBusy)
        }
        .controlSize(.regular)
        .voicedGlassGroup(spacing: 8)
    }

    private var metadata: String {
        var parts = [item.updatedAt.formatted(date: .abbreviated, time: .shortened)]
        if let appName = item.sourceApplication?.name { parts.append(appName) }
        return parts.joined(separator: " · ")
    }

    private func process(_ profile: TranscriptProcessingProfile) {
        processingTask?.cancel()
        processingProfile = profile
        refinementPreview = nil
        actionNotice = nil
        let input = normalizedText
        processingTask = Task { @MainActor in
            defer {
                processingProfile = nil
                processingTask = nil
            }
            do {
                let processed = try await onProcess(profile, input)
                try Task.checkCancellation()
                let normalized = processed.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalized.isEmpty, normalized != input else {
                    actionNotice = .success("No changes suggested")
                    return
                }
                previewSelection = .proposed
                refinementPreview = RefinementPreview(
                    profile: profile,
                    originalText: input,
                    proposedText: normalized
                )
            } catch is CancellationError {
            } catch {
                actionNotice = .warning("Couldn’t refine this capture")
            }
        }
    }

    private func applyRefinement(_ preview: RefinementPreview) {
        let originalText = preview.originalText
        let proposedText = preview.proposedText
        editText = proposedText
        onUpdate(item.id, proposedText)
        refinementPreview = nil
        lastAppliedRefinement = AppliedRefinement(originalText: originalText)
        actionNotice = .success("\(preview.profile.label) applied")
        registerRefinementUndo(originalText: originalText)
        isEditorFocused = true
    }

    private func cancelRefinement() {
        refinementPreview = nil
        actionNotice = .success("Kept original text")
        isEditorFocused = true
    }

    private func registerRefinementUndo(originalText: String) {
        undoManager?.registerUndo(withTarget: undoTarget) { _ in
            Task { @MainActor in
                onUpdate(item.id, originalText)
            }
        }
        undoManager?.setActionName("Apply Refinement")
    }

    private func undoLastRefinement() {
        guard let refinement = lastAppliedRefinement else { return }
        editText = refinement.originalText
        onUpdate(item.id, refinement.originalText)
        lastAppliedRefinement = nil
        actionNotice = .success("Refinement undone")
    }

    private func loadReminderListsRequestingAccess() {
        guard !isLoadingReminderLists else { return }
        isLoadingReminderLists = true
        Task { @MainActor in
            reminderLists = await onLoadReminderLists(true)
            isLoadingReminderLists = false
            if reminderLists.isEmpty {
                actionNotice = .warning("Couldn’t load Reminders lists")
            }
        }
    }

    private func exportToReminders(listID: String?) {
        guard !isExportingToReminders else { return }
        isExportingToReminders = true
        actionNotice = nil
        Task { @MainActor in
            switch await onExportToReminders(editText, listID) {
            case .success(let count):
                actionNotice = .success(count == 1 ? "Added 1 reminder" : "Added \(count) reminders")
            case .failure(let message):
                actionNotice = .warning(message)
            }
            isExportingToReminders = false
            if !reminderLists.isEmpty {
                reminderLists = await onLoadReminderLists(false)
            }
        }
    }
}

private struct RefinementPreview {
    let profile: TranscriptProcessingProfile
    let originalText: String
    let proposedText: String
}

private enum RefinementPreviewSelection {
    case proposed
    case original
}

private struct AppliedRefinement {
    let originalText: String
}

private enum CaptureActionNotice {
    case success(String)
    case warning(String)

    var message: String {
        switch self {
        case .success(let message), .warning(let message): message
        }
    }

    var symbolName: String {
        switch self {
        case .success: "checkmark.circle"
        case .warning: "exclamationmark.triangle"
        }
    }

    var isWarning: Bool {
        if case .warning = self { return true }
        return false
    }
}

@MainActor
private final class CaptureDetailUndoTarget: NSObject {}

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
            .accessibilityHint("Drag this text to another app, or use Copy")
            .accessibilityAddTraits(.isButton)
    }
}
