import SwiftUI
import TwinCore

/// Recursive search (Total Commander Alt+F7): find by name and/or
/// file content under the active pane's folder. Results are an
/// actionable list — reveal in the pane, open, or view — TC's
/// "feed to listbox".
struct FileSearchView: View {
    let root: URL
    /// Reveal: navigate the pane to the result's folder and select it.
    var onReveal: (URL) -> Void = { _ in }
    var onOpen: (URL) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var nameText = ""
    @State private var contentText = ""
    @State private var includeHidden = false
    @State private var matches: [FileSearchService.Match] = []
    @State private var scanned = 0
    @State private var isSearching = false
    @State private var truncated = false
    @State private var hasSearched = false
    @State private var selectedResult: String?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                VStack(alignment: .leading, spacing: 1) {
                    Text("Find Files").font(.headline)
                    Text("In \(root.path)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button("Close") { searchTask?.cancel(); dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Divider()

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Name contains")
                    TextField("e.g. invoice (empty = all)", text: $nameText)
                        .textFieldStyle(.roundedBorder)
                        .focused($nameFocused)
                        .accessibilityIdentifier("searchNameField")
                        .onSubmit(runSearch)
                }
                GridRow {
                    Text("Text in files")
                    TextField("e.g. TODO (text files only)", text: $contentText)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("searchContentField")
                        .onSubmit(runSearch)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            HStack(spacing: 12) {
                Toggle("Include hidden", isOn: $includeHidden)
                    .font(.caption)
                Spacer()
                if isSearching {
                    ProgressView().controlSize(.small)
                    Text("Searching…").font(.caption).foregroundStyle(.secondary)
                    Button("Stop") { searchTask?.cancel() }
                }
                Button("Search") { runSearch() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isSearching || (nameText.isEmpty && contentText.isEmpty))
            }
            .padding(12)

            Divider()
            results
            statusLine
        }
        .frame(minWidth: 640, minHeight: 520)
        // Design manual: the form's standard field (name) has
        // focus the moment the sheet opens.
        .onAppear { nameFocused = true }
    }

    @ViewBuilder
    private var results: some View {
        if matches.isEmpty {
            ContentUnavailableView(
                hasSearched ? "No Matches" : "Search This Folder Tree",
                systemImage: "magnifyingglass",
                description: Text(hasSearched
                    ? "Nothing under \(root.lastPathComponent) matches."
                    : "Type a name or a text to find, then press Search. Subfolders are included."))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Table(matches, selection: $selectedResult) {
                TableColumn("Name") { match in
                    HStack(spacing: 6) {
                        Image(systemName: match.isDirectory ? "folder" : "doc")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(match.url.lastPathComponent).lineLimit(1)
                            if let snippet = match.snippet {
                                Text(snippet)
                                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                }
                TableColumn("Folder") { match in
                    Text(match.url.deletingLastPathComponent().path)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                TableColumn("Size") { match in
                    Text(match.isDirectory ? "—" : SizeFormatting.string(forBytes: match.size))
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                .width(min: 60, ideal: 80)
                TableColumn("Modified") { match in
                    Text(match.modified, format: .dateTime.day().month(.abbreviated).year())
                        .font(.caption).foregroundStyle(.secondary)
                }
                .width(min: 90, ideal: 110)
            }
            .contextMenu(forSelectionType: String.self) { _ in
                if let match = selectedMatch {
                    Button("Show in Pane") { onReveal(match.url); dismiss() }
                    Button("Open") { onOpen(match.url); dismiss() }
                }
            } primaryAction: { _ in
                if let match = selectedMatch { onReveal(match.url); dismiss() }
            }
        }
    }

    private var statusLine: some View {
        HStack(spacing: 8) {
            if hasSearched {
                Text("\(matches.count) match(es) in \(scanned) scanned")
                if truncated {
                    Text("· stopped at the 500-result limit").foregroundStyle(.orange)
                }
            } else {
                Text("Recursive: subfolders included, packages skipped")
            }
            Spacer()
            if let match = selectedMatch {
                Button("Show in Pane") { onReveal(match.url); dismiss() }
                Button("Open") { onOpen(match.url); dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var selectedMatch: FileSearchService.Match? {
        matches.first { $0.id == selectedResult }
    }

    private func runSearch() {
        guard !isSearching else { return }
        var query = FileSearchService.Query()
        query.nameText = nameText
        query.contentText = contentText
        query.includeHidden = includeHidden
        isSearching = true
        hasSearched = true
        scanned = 0
        let folder = root
        // Same shape as PaneViewModel's background work: detached
        // search, results applied on the main actor.
        searchTask = Task.detached(priority: .userInitiated) {
            let outcome = FileSearchService.search(in: folder, query: query)
            if Task.isCancelled {
                await MainActor.run { isSearching = false }
                return
            }
            await MainActor.run {
                matches = outcome.matches
                scanned = outcome.scannedCount
                truncated = outcome.truncated
                isSearching = false
                selectedResult = outcome.matches.first?.id
            }
        }
    }
}
