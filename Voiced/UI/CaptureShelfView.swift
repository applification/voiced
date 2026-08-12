import AppKit
import SwiftUI

struct CaptureShelfView: View {
    var store: CaptureStore
    var permissions: SystemPermissionManager
    @Bindable var selection: CaptureShelfSelection
    var processingAvailability: TranscriptProcessingAvailability
    var onAddTyped: (String) -> CaptureItem?
    var onCopy: (String) -> Void
    var onInsert: (CaptureItem, String) async -> OutputResult
    var onProcess: (TranscriptProcessingProfile, String) async throws -> String
    var onLoadReminderLists: (Bool) async -> [ReminderListOption]
    var onExportToReminders: (String, String?) async -> ReminderExportResult

    @State private var searchText = ""
    @State private var draft = ""
    @State private var pendingRemoval: CaptureItem?
    @FocusState private var isComposerFocused: Bool
    @FocusState private var isSearchFocused: Bool

    private var filteredItems: [CaptureItem] {
        let statusItems = store.items.filter { $0.status == selection.status }
        guard !searchText.isEmpty else { return statusItems }
        return statusItems.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
                || ($0.sourceApplication?.name?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var selectedItem: CaptureItem? {
        guard let itemID = selection.itemID else { return nil }
        return store.item(id: itemID)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let issue = store.issue {
                storageIssueBanner(issue)
            }
            if !permissions.accessibilityAuthorized || !permissions.inputMonitoringAuthorized {
                permissionBanner
            }

            NavigationSplitView {
                statusSidebar
                    .navigationSplitViewColumnWidth(min: 190, ideal: 200, max: 220)
            } content: {
                captureList
                    .voicedWorkspacePane()
                    .navigationSplitViewColumnWidth(min: 250, ideal: 290, max: 350)
            } detail: {
                captureDetail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .voicedWorkspacePane()
            }
            .navigationSplitViewStyle(.balanced)
        }
        .frame(minWidth: 840, idealWidth: 900, minHeight: 500, idealHeight: 590)
        .voicedWindowMaterial()
        .onAppear {
            permissions.refresh()
            selectFirstVisibleItemIfNeeded()
            DispatchQueue.main.async { isComposerFocused = true }
        }
        .onChange(of: selection.status) {
            selectFirstVisibleItemIfNeeded(force: true)
        }
        .onChange(of: searchText) {
            selectFirstVisibleItemIfNeeded(force: true)
        }
        .alert(
            "Remove capture?",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ),
            presenting: pendingRemoval
        ) { item in
            Button("Remove Capture", role: .destructive) {
                _ = store.remove(id: item.id)
                pendingRemoval = nil
                selectFirstVisibleItemIfNeeded(force: true)
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: { _ in
            Text("This removes the item from the local shelf. This action cannot be undone.")
        }
    }

    private var statusSidebar: some View {
        List(selection: $selection.status) {
            Section("Shelf") {
                ForEach(CaptureStatus.allCases) { status in
                    HStack(spacing: 9) {
                        Image(systemName: status.symbolName)
                            .foregroundStyle(status == selection.status ? VoicedShelfStyle.signalMint : .secondary)
                            .frame(width: 16)
                        Text(status.label)
                        Spacer()
                        Text("\(store.items.lazy.filter { $0.status == status }.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .tag(status)
                }
            }

            Section("Shortcuts") {
                ShortcutHintRow(title: "Insert voice", keys: "R⌘", detail: "Right Command", symbol: "arrow.turn.down.left")
                ShortcutHintRow(title: "Save voice", keys: "⇧ R⌘", detail: "Shift + Right Command", symbol: "waveform")
                ShortcutHintRow(title: "Save selection", keys: "⇧ ⇧", detail: "Double Shift", symbol: "selection.pin.in.out")
                ShortcutHintRow(title: "Toggle shelf", keys: "⌥ Space", detail: "Option + Space", symbol: "rectangle.rightthird.inset.filled")
            }
        }
        .listStyle(.sidebar)
    }

    private var captureList: some View {
        VStack(spacing: 0) {
            searchField
            composer

            if filteredItems.isEmpty {
                emptyState
            } else {
                List(filteredItems, selection: $selection.itemID) { item in
                    CaptureShelfRow(item: item, isSelected: selection.itemID == item.id)
                        .tag(item.id)
                        .contextMenu {
                            captureContextMenu(item)
                        }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .onDeleteCommand {
                    if let selectedItem { pendingRemoval = selectedItem }
                }
            }
        }
        .navigationTitle(selection.status.label)
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search captures", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .voicedGlassSurface(cornerRadius: 9, interactive: true)
        .padding(.horizontal, 10)
        .padding(.top, 9)
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Type a capture", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .focused($isComposerFocused)
                .onSubmit(addTypedCapture)

            Button(action: addTypedCapture) {
                Image(systemName: "arrow.up")
                    .font(.callout.weight(.semibold))
                    .frame(width: 16, height: 16)
            }
            .voicedGlassButton(prominent: true, tint: VoicedShelfStyle.signalMint)
            .buttonBorderShape(.circle)
            .disabled(!canAddDraft)
            .help("Add to Inbox")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .voicedGlassSurface(cornerRadius: 12, interactive: true)
        .padding(.horizontal, 10)
        .padding(.top, 7)
        .padding(.bottom, 7)
    }

    private var canAddDraft: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addTypedCapture() {
        guard canAddDraft, let item = onAddTyped(draft) else { return }
        draft = ""
        selection.select(item)
        isComposerFocused = true
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(emptyTitle, systemImage: selection.status.symbolName)
        } description: {
            Text(emptyDescription)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyTitle: String {
        switch selection.status {
        case .inbox: "Inbox is clear"
        case .next: "Nothing queued next"
        case .done: "Nothing completed yet"
        }
    }

    private var emptyDescription: String {
        switch selection.status {
        case .inbox: "Speak, select text, or type above to keep something."
        case .next: "Move captures here when you want them close at hand."
        case .done: "Inserted captures appear here automatically."
        }
    }

    @ViewBuilder
    private var captureDetail: some View {
        if let item = selectedItem {
            CaptureShelfDetailView(
                item: item,
                processingAvailability: processingAvailability,
                onUpdate: { id, text in store.updateText(id: id, text: text) },
                onMove: moveCapture,
                onCopy: onCopy,
                onInsert: { item, text in
                    let result = await onInsert(item, text)
                    if result == .inserted, let updated = store.item(id: item.id) {
                        selection.select(updated)
                    }
                    return result
                },
                onProcess: onProcess,
                onLoadReminderLists: onLoadReminderLists,
                onExportToReminders: onExportToReminders,
                onRemove: { pendingRemoval = $0 }
            )
            .id(item.id)
        } else {
            ContentUnavailableView {
                Label("Choose a capture", systemImage: "text.cursor")
            } description: {
                Text("Edit it, refine it, or send it back to your work.")
            }
        }
    }

    @ViewBuilder
    private func captureContextMenu(_ item: CaptureItem) -> some View {
        Button("Copy") { onCopy(item.text) }
        Button("Insert") {
            Task { @MainActor in
                let result = await onInsert(item, item.text)
                if result == .inserted, let updated = store.item(id: item.id) {
                    selection.select(updated)
                }
            }
        }
        Divider()
        Menu("Move To") {
            ForEach(CaptureStatus.allCases) { status in
                Button(status.label) { moveCapture(item.id, status) }
                    .disabled(item.status == status)
            }
        }
        Divider()
        Button("Remove", role: .destructive) { pendingRemoval = item }
    }

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Finish capture permissions")
                    .font(.callout.weight(.semibold))
                Text("Accessibility reads selections and inserts text. Input Monitoring listens for global shortcuts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !permissions.accessibilityAuthorized {
                Button("Accessibility") { permissions.openAccessibilitySettings() }
                    .voicedGlassButton()
            }
            if !permissions.inputMonitoringAuthorized {
                Button("Input Monitoring") { permissions.openInputMonitoringSettings() }
                    .voicedGlassButton()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .voicedGlassSurface(cornerRadius: 12, tint: Color.orange.opacity(0.06))
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }

    private func storageIssueBanner(_ issue: CaptureStoreIssue) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(issue.message)
                .font(.caption)
            Spacer()
            Button("Dismiss") { store.clearIssue() }
                .voicedGlassButton()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .voicedGlassSurface(cornerRadius: 12, tint: Color.orange.opacity(0.06))
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }

    private func moveCapture(_ id: UUID, _ status: CaptureStatus) {
        store.move(id: id, to: status)
        if let updated = store.item(id: id) {
            selection.select(updated)
        }
    }

    private func selectFirstVisibleItemIfNeeded(force: Bool = false) {
        if !force,
           let itemID = selection.itemID,
           filteredItems.contains(where: { $0.id == itemID }) {
            return
        }
        selection.itemID = filteredItems.first?.id
    }
}

private struct CaptureShelfRow: View {
    let item: CaptureItem
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: item.source.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? VoicedShelfStyle.signalMint : .secondary)
                .frame(width: 18, height: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.text.replacingOccurrences(of: "\n", with: " "))
                    .lineLimit(1)
                    .font(.callout)
                HStack(spacing: 5) {
                    Text(item.source.label)
                    if let appName = item.sourceApplication?.name {
                        Text("·")
                        Text(appName)
                    }
                    Spacer(minLength: 4)
                    CaptureRelativeTimeText(date: item.updatedAt)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 38, alignment: .topLeading)
        .padding(.vertical, 6)
    }
}

private struct ShortcutHintRow: View {
    let title: String
    let keys: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .frame(width: 16)
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(keys)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .help(detail)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(detail)")
    }
}
