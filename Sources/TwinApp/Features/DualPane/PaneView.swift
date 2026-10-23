import QuickLook
import SwiftUI
import UniformTypeIdentifiers

struct PaneView: View {
    @ObservedObject var viewModel: PaneViewModel
    var isActive: Bool

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
        }
        .border(isActive ? Color.accentColor : Color.clear, width: 1)
        .overlay {
            if viewModel.isDropTargeted {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .background(Color.accentColor.opacity(0.08))
                    .allowsHitTesting(false)
            }
        }
        .focusable()
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

            HStack {
                Text(viewModel.currentURL.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("\(viewModel.filteredItems.count) items")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            PaneSearchField(text: $viewModel.searchText)
        }
        .padding(6)
        .background(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
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
        switch viewModel.viewMode {
        case .list:
            listView
        case .icon:
            iconView
        }
    }

    private var listView: some View {
        List(viewModel.filteredItems, id: \.url, selection: $viewModel.selection) { item in
            HStack {
                Image(systemName: item.isDirectory ? "folder.fill" : "doc")
                    .foregroundStyle(item.isDirectory ? .blue : .secondary)
                Text(item.name)
                    .lineLimit(1)
                Spacer()
                if !item.isDirectory {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(item.size), countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { viewModel.open(item) }
            .onDrag { viewModel.makeDragProvider(for: item) }
        }
        .listStyle(.plain)
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
