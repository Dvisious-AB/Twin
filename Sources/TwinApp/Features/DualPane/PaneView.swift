import QuickLook
import SwiftUI
import UniformTypeIdentifiers

struct PaneView: View {
    @ObservedObject var viewModel: PaneViewModel
    var isActive: Bool
    var onRequestPaneSwitch: () -> Void = {}

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
        .border(isActive ? Color.accentColor : Color.clear, width: 2)
        .overlay {
            if viewModel.isDropTargeted {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .background(Color.accentColor.opacity(0.08))
                    .allowsHitTesting(false)
            }
        }
        .focusable()
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
                Button { viewModel.goUp() } label: {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderless)
                .help("Go up")

                breadcrumbs
                Spacer()
                viewModeToggle
                Button { viewModel.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }

            PaneSearchField(
                text: $viewModel.searchText,
                onFocusChange: { viewModel.isSearchEditing = $0 },
                focusTrigger: viewModel.searchFocusTrigger
            )
        }
        .padding(6)
        .background(isActive ? Color.accentColor.opacity(0.18) : Color.clear)
    }

    private var breadcrumbs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(Array(viewModel.breadcrumbs.enumerated()), id: \.element.id) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Button(crumb.name) {
                        viewModel.navigateToBreadcrumb(crumb)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .lineLimit(1)
                    .help(crumb.url.path)
                }
            }
        }
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
        .frame(width: 72)
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
                Button("Try Again") { viewModel.refresh() }
            }
        } else {
            paneContent
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
        viewModel.filteredItems.sorted(using: sortOrder)
    }

    private var listView: some View {
        Table(sortedItems, selection: $viewModel.selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { item in
                HStack(spacing: 6) {
                    Image(systemName: item.isDirectory ? "folder.fill" : "doc")
                        .foregroundStyle(item.isDirectory ? Color.blue : Color.secondary)
                    Text(item.name).lineLimit(1)
                }
            }
            TableColumn("Size", value: \.size) { item in
                Text(item.isDirectory ? "--" : ByteCountFormatter.string(fromByteCount: Int64(item.size), countStyle: .file))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .width(min: 70, ideal: 90)
            TableColumn("Modified", value: \.modifiedDate) { item in
                Text(item.modifiedDate, format: .dateTime.year().month().day().hour().minute())
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .width(min: 130, ideal: 150)
        }
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
                ForEach(viewModel.filteredItems, id: \.url) { item in
                    VStack(spacing: 6) {
                        Image(systemName: item.isDirectory ? "folder.fill" : "doc")
                            .font(.system(size: 32))
                            .foregroundStyle(item.isDirectory ? .blue : .secondary)
                        Text(item.name)
                            .font(.caption)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 84, height: 84)
                    .background(
                        viewModel.selection.contains(item.url)
                            ? Color.accentColor.opacity(0.2)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if viewModel.selection.contains(item.url) {
                            viewModel.selection.remove(item.url)
                        } else {
                            viewModel.selection.insert(item.url)
                        }
                    }
                    .onTapGesture(count: 2) { viewModel.open(item) }
                    .onDrag { viewModel.makeDragProvider(for: item) }
                }
            }
            .padding(10)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Text("\(viewModel.filteredItems.count) items")
            if !viewModel.selection.isEmpty {
                Text("· \(viewModel.selection.count) selected")
            }
            if let summary = viewModel.lastOperationSummary {
                Text("· \(summary)").foregroundStyle(.orange)
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
        return ByteCountFormatter.string(fromByteCount: capacity, countStyle: .file) + " free"
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
