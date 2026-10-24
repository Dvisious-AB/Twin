import QuickLook
import SwiftUI
import TwinCore
import UniformTypeIdentifiers

struct PaneView: View {
    @ObservedObject var viewModel: PaneViewModel
    var isActive: Bool
    var onRequestPaneSwitch: () -> Void = {}
    var onChooseFolder: () -> Void = {}
    /// Fired when the user interacts with this pane's selection, so the
    /// clicked/keyboard-used pane becomes the active one. The container
    /// tap gesture in DualPaneView is not enough: Table consumes row taps.
    var onActivate: () -> Void = {}
    @FocusState var listFocused: Bool

    private let iconColumns = [
        GridItem(.adaptive(minimum: 76, maximum: 110), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            if viewModel.isPerformingOperation {
                progressBar
            }
            statusBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .border(isActive ? Color.accentColor : Color.clear, width: 2)
        .overlay {
            if viewModel.isDropTargeted {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .background(Color.accentColor.opacity(0.08))
                    .allowsHitTesting(false)
            }
        }
        // Focus lives on the Table/ScrollView themselves (below), not
        // here: a focusable container left the keyboard on a static
        // text and arrow keys did nothing at all.
        .onAppear { if isActive { listFocused = true } }
        .onChange(of: isActive) { _, active in if active { listFocused = true } }
        .onChange(of: viewModel.selection) { _, _ in onActivate() }
        .onKeyPress(.return) {
            guard !viewModel.selection.isEmpty else { return .ignored }
            viewModel.openFirstSelected()
            return .handled
        }
        .onKeyPress(phases: .down) { press in
            // Arrow/Home/End navigation. The pane root holds focus (not
            // the Table), so the Table's built-in arrow handling never
            // engages — move the selection explicitly or ↑/↓ are dead.
            let delta: Int
            switch press.key {
            case .upArrow: delta = -1
            case .downArrow: delta = 1
            case .pageUp: delta = -10
            case .pageDown: delta = 10
            case .home: delta = -sortedItems.count
            case .end: delta = sortedItems.count
            default: return .ignored
            }
            // Ctrl+PageUp/PageDown keep their TC meaning (handled below).
            guard !press.modifiers.contains(.control) else { return .ignored }
            guard press.modifiers.isSubset(of: [.shift]) else { return .ignored }
            // In list mode the focused Table moves natively — handling
            // it here too would move twice per keypress. The explicit
            // mover exists for the icon grid, which has no native keys.
            guard viewModel.viewMode == .icon else { return .ignored }
            moveSelection(by: delta, extend: press.modifiers.contains(.shift))
            return .handled
        }
        .onKeyPress(phases: .down) { press in
            // Mac's Delete key (backspace, U+007F) = up one level, as in TC.
            // The Table swallows the .delete key equivalent, so match the
            // character directly. Deleting files is Cmd+Delete in the bar.
            guard press.key == .delete || press.characters.contains("\u{7F}") else { return .ignored }
            guard press.modifiers.isEmpty else { return .ignored }
            viewModel.goUp()
            return .handled
        }
        .onKeyPress(phases: .down) { press in
            // Ctrl+backslash: jump to root (Total Commander). Matched by
            // character so non-US keyboard layouts still work.
            guard press.modifiers.contains(.control),
                  press.characters.contains("\\") || press.key == KeyEquivalent(Character("\\"))
            else { return .ignored }
            viewModel.goToRoot()
            return .handled
        }
        .onKeyPress(.pageUp, phases: .down) { press in
            guard press.modifiers.contains(.control) else { return .ignored }
            viewModel.goUp()
            return .handled
        }
        .onKeyPress(.pageDown, phases: .down) { press in
            guard press.modifiers.contains(.control) else { return .ignored }
            viewModel.openFirstSelected()
            return .handled
        }
        .onKeyPress(.leftArrow, phases: .down) { press in
            guard press.modifiers.contains(.option) else { return .ignored }
            viewModel.goBack()
            return .handled
        }
        .onKeyPress(.rightArrow, phases: .down) { press in
            guard press.modifiers.contains(.option) else { return .ignored }
            viewModel.goForward()
            return .handled
        }
        .onKeyPress(.tab) {
            // Tab switches pane — unless the user is typing in the filter field.
            guard !viewModel.isSearchEditing else { return .ignored }
            onRequestPaneSwitch()
            return .handled
        }
        .onKeyPress(.space) {
            viewModel.previewSelected()
            return viewModel.quickLookURL != nil ? .handled : .ignored
        }
        .quickLookPreview($viewModel.quickLookURL)
        .sheet(isPresented: Binding(
            get: { viewModel.editingURL != nil },
            set: { if !$0 { viewModel.editingURL = nil } }
        )) {
            if let url = viewModel.editingURL {
                TextEditorView(url: url) { viewModel.refresh() }
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $viewModel.isDropTargeted) { providers in
            Task { @MainActor in
                _ = await viewModel.handleDrop(providers: providers)
            }
            return true
        }
    }

    // MARK: - Header: breadcrumbs + controls

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Button { viewModel.goBack() } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(!viewModel.canGoBack)
                .help("Back (Alt+Left)")
                Button { viewModel.goForward() } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(!viewModel.canGoForward)
                .help("Forward (Alt+Right)")
                Button { viewModel.goUp() } label: {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderless)
                .help("Up one level (Backspace / Delete key)")

                breadcrumbs
                Spacer()
                viewModeToggle
                Button { viewModel.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }

            // The filter field only takes vertical space while it is
            // being used (Cmd+F reveals it) — UX review P2-14.
            if viewModel.isSearchFieldVisible || !viewModel.searchText.isEmpty {
                PaneSearchField(
                    text: $viewModel.searchText,
                    onFocusChange: { focused in
                        viewModel.isSearchEditing = focused
                        if !focused, viewModel.searchText.isEmpty {
                            viewModel.isSearchFieldVisible = false
                        }
                    },
                    focusTrigger: viewModel.searchFocusTrigger
                )
            }

            if viewModel.isInSandboxContainer {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("Sandbox container — not your files.")
                        .font(.caption)
                    Spacer()
                    Button("Choose Folder…") { onChooseFolder() }
                        .font(.caption)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(6)
        .background(isActive ? Color.accentColor.opacity(0.18) : Color.clear)
    }

    private var breadcrumbs: some View {
        BreadcrumbBar(crumbs: viewModel.breadcrumbs) { viewModel.navigateToBreadcrumb($0) }
    }

    private var viewModeToggle: some View {
        Picker("View", selection: $viewModel.viewMode) {
            ForEach(PaneViewMode.allCases) { mode in
                Image(systemName: mode.systemImage)
                    .tag(mode)
                    .help(mode.label)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 64)
        .help("Toggle list / icon view")
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.loadState.isError || viewModel.loadState == .empty {
            ContentUnavailableView {
                Label(
                    viewModel.loadState == .empty ? "Folder is Empty" : "Can't Read Folder",
                    systemImage: viewModel.loadState == .empty ? "folder" : "exclamationmark.triangle"
                )
            } description: {
                Text(viewModel.loadState.userMessage)
            } actions: {
                if viewModel.loadState.isError {
                    Button("Try Again") { viewModel.refresh() }
                }
            }
        } else {
            paneContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var paneContent: some View {
        if !viewModel.searchText.isEmpty, viewModel.filteredItems.isEmpty,
           !viewModel.loadState.isError, viewModel.loadState != .empty {
            ContentUnavailableView {
                Label("No Results", systemImage: "magnifyingglass")
            } description: {
                Text("Nothing in this folder matches \"\(viewModel.searchText)\".")
            } actions: {
                Button("Clear Filter") { viewModel.searchText = "" }
            }
        } else {
            paneContentSwitch
        }
    }

    @ViewBuilder
    private var paneContentSwitch: some View {
        switch viewModel.viewMode {
        case .list:
            listView
        case .icon:
            iconView
        }
    }

    @State private var sortOrder = [KeyPathComparator(\FileItem.name)]

    private var sortedItems: [FileItem] {
        // Standard: directories first, files after (Finder/TC convention),
        // then the chosen column order inside each group.
        viewModel.filteredItems
            .sorted(using: sortOrder)
            .sorted { a, b in a.isDirectory && !b.isDirectory }
    }

    /// Name with the filter hit highlighted and the selection bolded
    /// (UX review P0-4 + P1-7).
    private func highlightedName(for item: FileItem) -> AttributedString {
        var text = AttributedString(item.name)
        if viewModel.selection.contains(item.url) {
            text.font = .body.bold()
        }
        let query = viewModel.searchText
        if !query.isEmpty,
           let range = item.name.range(of: query, options: .caseInsensitive),
           let attributedRange = Range(range, in: text) {
            text[attributedRange].font = .body.bold()
            text[attributedRange].foregroundColor = .accentColor
        }
        return text
    }

    /// Moves the cursor in display order. Shift extends the selection
    /// (TC marking); without a selection, Down starts at the first row.
    private func moveSelection(by delta: Int, extend: Bool) {
        let items = sortedItems
        guard !items.isEmpty else { return }
        let urls = items.map(\.url)
        guard let index = urls.firstIndex(where: { viewModel.selection.contains($0) }) else {
            viewModel.selection = [delta >= 0 ? items[0].url : items[items.count - 1].url]
            return
        }
        let target = min(max(index + delta, 0), items.count - 1)
        if extend {
            viewModel.selection.insert(items[target].url)
        } else {
            viewModel.selection = [items[target].url]
        }
    }

    private var listView: some View {
        Table(sortedItems, selection: $viewModel.selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { item in
                HStack(spacing: 6) {
                    FileItemIcon(item: item)
                    Text(highlightedName(for: item))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(item.url.path)
                    if let badge = viewModel.gitBadge(for: item) {
                        Text(badge.rawValue)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(badge == .untracked ? Color.orange : Color.red)
                            .clipShape(Capsule())
                    }
                }
                // Drag source for the list view (was icon-view only,
                // so list drags silently never started — found while
                // proving Option-drag for #12). Table rows honour
                // .draggable, not .onDrag, on the cell content.
                .draggable(item.url)
            }
            TableColumn("Size", value: \.size) { item in
                Text(viewModel.directorySizeText(for: item))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .help(item.isDirectory && DirectorySizeService.isProtectedFolder(item.url)
                        ? "Size is not calculated for macOS-protected folders (would trigger a permission prompt). "
                            + "Open the folder to see sizes inside."
                        : "")
            }
            .width(min: 70, ideal: 90)
            TableColumn("Type") { item in
                Text(item.isDirectory
                    ? "Folder"
                    : (item.url.pathExtension.isEmpty ? "File" : item.url.pathExtension.uppercased()))
                    .foregroundStyle(.secondary)
            }
            .width(min: 50, ideal: 64)
            TableColumn("Modified", value: \.modifiedDate) { item in
                Text(item.modifiedDate, format: .dateTime.day().month(.abbreviated).hour().minute())
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .width(min: 130, ideal: 150)
        }
        // No alternating filler rows below the last real row
        // (they read as ghost/missing files — UX review P1-10).
        .tableStyle(.inset(alternatesRowBackgrounds: false))
        // The Table itself takes keyboard focus so its native arrow
        // navigation works from pane entry, no click needed.
        .focused($listFocused)
        .onTapGesture(count: 2) { viewModel.openFirstSelected() }
        .contextMenu(forSelectionType: URL.self) { _ in
            Button("Open") { viewModel.openFirstSelected() }
            Button("Quick Look") { viewModel.previewSelected() }
            Button("Show in Finder") {
                if let url = viewModel.selection.first { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
        } primaryAction: { _ in
            viewModel.openFirstSelected()
        }
    }

    private var iconView: some View {
        ScrollView {
            LazyVGrid(columns: iconColumns, spacing: 14) {
                ForEach(sortedItems, id: \.url) { item in
                    VStack(spacing: 4) {
                        FileItemIcon(item: item, size: 32)
                        Text(item.name)
                            .font(.caption)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        Text(viewModel.directorySizeText(for: item))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .frame(width: 84, height: 92)
                    .background(
                        viewModel.selection.contains(item.url)
                            ? Color.accentColor.opacity(isActive ? 0.35 : 0.15)
                            : Color.clear
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                viewModel.selection.contains(item.url) ? Color.accentColor : Color.clear,
                                lineWidth: 1.5
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Finder/TC semantics: plain click replaces the
                        // selection, Cmd-click toggles (UX review P1-8).
                        if NSApplication.shared.currentEvent?.modifierFlags.contains(.command) == true {
                            if viewModel.selection.contains(item.url) {
                                viewModel.selection.remove(item.url)
                            } else {
                                viewModel.selection.insert(item.url)
                            }
                        } else {
                            viewModel.selection = [item.url]
                        }
                    }
                    .onTapGesture(count: 2) { viewModel.open(item) }
                    .onDrag { viewModel.makeDragProvider(for: item) }
                }
            }
            .padding(10)
        }
        // Grid cells are not focusable; the scroll view takes focus
        // and arrow keys bubble to the pane's explicit moveSelection.
        .focusable()
        .focused($listFocused)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            if viewModel.searchText.isEmpty {
                Text("\(viewModel.filteredItems.count) items")
            } else {
                Text("\(viewModel.filteredItems.count) of \(viewModel.items.count) items · filter: \"\(viewModel.searchText)\"")
            }
            if !viewModel.selection.isEmpty {
                Text("· \(viewModel.selection.count) selected")
                let selectedBytes = viewModel.items
                    .filter { viewModel.selection.contains($0.url) }
                    .reduce(UInt64(0)) { total, item in
                        total + (item.isDirectory
                            ? (viewModel.directorySizes[item.url.path] ?? 0)
                            : UInt64(item.size))
                    }
                if selectedBytes > 0 {
                    Text("· \(SizeFormatting.string(forBytes: selectedBytes))")
                }
            }
            if let summary = viewModel.lastOperationSummary {
                Text("· \(summary)").foregroundStyle(.orange)
            }
            if let insights = viewModel.insights, !insights.permissionRisks.isEmpty {
                Label("\(insights.permissionRisks.count) risk", systemImage: "exclamationmark.shield")
                    .foregroundStyle(.orange)
                    .help("Files anyone can write to — open Assistant for details")
            }
            if let insights = viewModel.insights, !insights.orphanFiles.isEmpty {
                Text(insights.orphanFiles.count == 1
                    ? "· 1 old file"
                    : "· \(insights.orphanFiles.count) old files")
                    .help("Loose files untouched for over 90 days — Assistant can collect them into a catalog")
            }
            Spacer()
            if let free = freeSpaceText {
                Text(free)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var freeSpaceText: String? {
        let values = try? viewModel.currentURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let capacity = values?.volumeAvailableCapacityForImportantUsage else { return nil }
        return SizeFormatting.string(forBytes: capacity) + " free"
    }

    // MARK: - Progress

    private var progressBar: some View {
        VStack(spacing: 4) {
            if let label = viewModel.operationLabel {
                HStack {
                    Text(label).font(.caption)
                    Spacer()
                    Text("\(Int(viewModel.operationProgress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Button("Cancel") { viewModel.cancelOperation() }
                        .controlSize(.small)
                }
            }
            ProgressView(value: viewModel.operationProgress, total: 1.0)
                .progressViewStyle(.linear)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
