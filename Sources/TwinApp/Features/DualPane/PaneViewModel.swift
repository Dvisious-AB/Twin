import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct FileItem: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: UInt64
    let modifiedDate: Date
}

enum PaneViewMode: String, CaseIterable, Identifiable {
    case list
    case icon
    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .list: return "list.bullet"
        case .icon: return "square.grid.2x2"
        }
    }
    var label: String {
        switch self {
        case .list: return "List"
        case .icon: return "Icons"
        }
    }
}

struct Breadcrumb: Identifiable, Hashable {
    var id: String { url.path }
    let name: String
    let url: URL
}

@MainActor
final class PaneViewModel: ObservableObject {
    @Published var currentURL: URL
    @Published var items: [FileItem] = []
    @Published var selection = Set<URL>()
    @Published var viewMode: PaneViewMode = .list
    @Published var navigationPath = NavigationPath()
    @Published var quickLookURL: URL?
    @Published var searchText: String = ""
    @Published var isSearchEditing = false
    @Published var searchFocusTrigger = 0
    @Published var lastOperationSummary: String?
    @Published var directorySizes: [String: UInt64] = [:]
    private var backHistory: [URL] = []
    private var forwardHistory: [URL] = []
    var canGoBack: Bool { !backHistory.isEmpty }
    var canGoForward: Bool { !forwardHistory.isEmpty }
    @Published var editingURL: URL?
    @Published var computingSizes: Set<String> = []

    func focusSearch() { searchFocusTrigger += 1 }
    @Published var loadState: DirectoryLoadState = .loaded(itemCount: 0)

    var filteredItems: [FileItem] {
        PaneSearch.filter(items, query: searchText)
    }

    // Drag-drop / file-operation progress
    @Published var isDropTargeted = false
    @Published var isPerformingOperation = false
    @Published var operationProgress: Double = 0 // 0...1
    @Published var operationLabel: String?

    private let bookmarkStore: BookmarkStore

    init(initialPath: URL, bookmarkStore: BookmarkStore = .shared) {
        self.bookmarkStore = bookmarkStore
        // Resolve persisted bookmark at start (FileSystemEngineer requirement).
        let resolved = bookmarkStore.resolveBookmark(for: initialPath) ?? initialPath
        self.currentURL = resolved
        _ = bookmarkStore.startAccessing(resolved)
        refresh()
    }

    // MARK: - Breadcrumbs

    /// True when the pane sits in the app's sandbox container — not user files.
    var isInSandboxContainer: Bool {
        currentURL.path.contains("/Library/Containers/")
    }

    /// Folder to start breadcrumb display from. Inside the sandbox container,
    /// everything up to the container's Data folder is noise — hide it.
    private var breadcrumbRoot: URL {
        let components = currentURL.pathComponents
        guard let containersIndex = components.firstIndex(of: "Containers"),
              components.count > containersIndex + 2 else { return currentURL }
        // .../Containers/<bundle-id>/Data
        var url = URL(fileURLWithPath: "/")
        for component in components[1...(containersIndex + 2)] {
            url.appendPathComponent(component)
        }
        return url
    }

    var breadcrumbs: [Breadcrumb] {
        // Inside the container, start crumbs at the Data folder.
        if isInSandboxContainer {
            let root = breadcrumbRoot
            if currentURL.path.hasPrefix(root.path) {
                var crumbs = [Breadcrumb(name: "Twin Data", url: root)]
                var building = root
                let relative = currentURL.path.dropFirst(root.path.count)
                for component in relative.split(separator: "/") {
                    building.appendPathComponent(String(component))
                    crumbs.append(Breadcrumb(name: String(component), url: building))
                }
                return crumbs
            }
        }
        let components = currentURL.pathComponents
        guard !components.isEmpty else {
            return [Breadcrumb(name: currentURL.lastPathComponent, url: currentURL)]
        }
        var crumbs: [Breadcrumb] = []
        var building = URL(fileURLWithPath: "/")
        // Root crumb
        crumbs.append(Breadcrumb(name: "/", url: building))
        for component in components where component != "/" {
            building.appendPathComponent(component)
            crumbs.append(Breadcrumb(name: component, url: building))
        }
        return crumbs
    }

    func navigateToBreadcrumb(_ crumb: Breadcrumb) {
        navigate(to: crumb.url)
    }

    // MARK: - Listing

    func refresh() {
        let contents: [URL]
        do {
            contents = try TwinCore.fileCoordinator.contentsOfDirectory(at: currentURL)
        } catch {
            items = []
            loadState = DirectoryLoadState.classify(error: error, for: currentURL)
            return
        }
        items = contents.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            return FileItem(
                url: url,
                name: url.lastPathComponent,
                isDirectory: values?.isDirectory ?? false,
                size: UInt64(values?.fileSize ?? 0),
                modifiedDate: values?.contentModificationDate ?? .distantPast
            )
        }
        .sorted { a, b in a.isDirectory != b.isDirectory ? a.isDirectory : a.name.lowercased() < b.name.lowercased() }
        loadState = DirectoryLoadState.state(contents: contents, for: currentURL)
        // Keyboard-first: preselect the first row so arrows work immediately.
        if selection.isEmpty, let first = items.first {
            selection = [first.url]
        }
        computeDirectorySizes()
    }

    /// Background directory sizes (cached in DirectorySizeService).
    private func computeDirectorySizes() {
        let directories = items.filter(\.isDirectory).map(\.url)
        for url in directories where directorySizes[url.path] == nil && !computingSizes.contains(url.path) {
            computingSizes.insert(url.path)
            Task { [weak self] in
                let size = await DirectorySizeService.shared.size(for: url)
                await MainActor.run {
                    self?.directorySizes[url.path] = size
                    self?.computingSizes.remove(url.path)
                }
            }
        }
    }

    func directorySizeText(for item: FileItem) -> String {
        guard item.isDirectory else {
            return ByteCountFormatter.string(fromByteCount: Int64(item.size), countStyle: .file)
        }
        if let size = directorySizes[item.url.path] {
            return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }
        return computingSizes.contains(item.url.path) ? "…" : "--"
    }

    func navigate(to url: URL) {
        navigate(to: url, recordHistory: true)
    }

    private func navigate(to url: URL, recordHistory: Bool) {
        // Persist a security-scoped bookmark for the folder we enter,
        // and start accessing it so the sandbox keeps access across launches.
        if recordHistory, url != currentURL {
            backHistory.append(currentURL)
            forwardHistory.removeAll()
        }
        bookmarkStore.saveBookmark(for: url)
        let resolved = bookmarkStore.startAccessing(url)
        currentURL = resolved
        selection.removeAll()
        refresh()
    }

    /// Alt+Left in Total Commander: previous folder in history.
    func goBack() {
        guard let previous = backHistory.popLast() else { return }
        forwardHistory.append(currentURL)
        navigate(to: previous, recordHistory: false)
    }

    /// Alt+Right: next folder in history.
    func goForward() {
        guard let next = forwardHistory.popLast() else { return }
        backHistory.append(currentURL)
        navigate(to: next, recordHistory: false)
    }

    /// Ctrl+backslash in Total Commander: jump to root.
    func goToRoot() {
        navigate(to: URL(fileURLWithPath: "/"))
    }

    func goUp() {
        let child = currentURL
        let parent = currentURL.deletingLastPathComponent()
        guard parent.path != currentURL.path else { return }
        navigate(to: parent)
        // Total Commander places the cursor on the folder you came from.
        if items.contains(where: { $0.url == child }) {
            selection = [child]
        }
    }

    func openFirstSelected() {
        guard let url = selection.sorted(by: { $0.path < $1.path }).first,
              let item = items.first(where: { $0.url == url }) else { return }
        open(item)
    }

    /// Quick Look (Space) for the first selected file.
    func previewSelected() {
        guard let url = selection.sorted(by: { $0.path < $1.path }).first else { return }
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        if !isDirectory {
            quickLookURL = url
        }
    }

    func open(_ item: FileItem) {
        if item.isDirectory {
            navigate(to: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    // MARK: - Copy / Move with progress

    func copySelected(to dest: URL) async {
        await performFileOperation(urls: Array(selection), to: dest, move: false)
    }

    func moveSelected(to dest: URL) async {
        await performFileOperation(urls: Array(selection), to: dest, move: true)
    }

    /// Copies/moves `urls` into `dest`, publishing progress 0...1 as it goes.
    func performFileOperation(urls: [URL], to dest: URL, move: Bool) async {
        guard !urls.isEmpty, !isPerformingOperation else { return }
        isPerformingOperation = true
        operationProgress = 0
        operationLabel = move ? "Moving \(urls.count) item(s)…" : "Copying \(urls.count) item(s)…"
        defer {
            isPerformingOperation = false
            operationLabel = nil
            operationProgress = 0
        }

        let total = Double(urls.count)
        var skipped = 0
        for (index, url) in urls.enumerated() {
            // Yield so SwiftUI can render the progress update.
            await Task.yield()
            let target = dest.appendingPathComponent(url.lastPathComponent)
            if FileManager.default.fileExists(atPath: target.path) {
                skipped += 1
                operationProgress = Double(index + 1) / total
                continue
            }
            do {
                if move {
                    try TwinCore.fileCoordinator.moveItem(at: url, to: target)
                } else {
                    try TwinCore.fileCoordinator.copyItem(at: url, to: target)
                }
            } catch {
                // Keep going for remaining items; progress still advances.
                continue
            }
            operationProgress = Double(index + 1) / total
        }
        let done = urls.count - skipped
        lastOperationSummary = skipped > 0
            ? "\(move ? "Moved" : "Copied") \(done), skipped \(skipped) existing"
            : nil
        refresh()
    }

    // MARK: - Drag & Drop

    /// Handles a drop of file providers onto this pane.
    /// Returns `true` if the drop was accepted.
    func handleDrop(providers: [NSItemProvider]) async -> Bool {
        let urls = await DragDropSupport.loadFileURLs(from: providers)
        // Filter out drops of items already in this folder (no-op self-drop).
        let incoming = urls.filter { $0.deletingLastPathComponent() != currentURL }
        guard !incoming.isEmpty else { return false }
        await performFileOperation(urls: incoming, to: currentURL, move: false)
        return true
    }

    // MARK: - File actions (keyboard-first)

    func compressSelected() {
        let urls = Array(selection)
        guard !urls.isEmpty else { return }
        do {
            let archive = try FileActionService.compress(items: urls, in: currentURL)
            lastOperationSummary = "Packed \(archive.lastPathComponent)"
        } catch {
            lastOperationSummary = error.localizedDescription
        }
        refresh()
    }

    func createMD5ForSelected() {
        let files = selection.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == false
        }
        guard !files.isEmpty else { return }
        var created = 0
        for url in files {
            if (try? FileActionService.createMD5File(for: url)) != nil { created += 1 }
        }
        lastOperationSummary = created > 0 ? "Created \(created) MD5 file(s)" : "MD5 failed"
        refresh()
    }

    func trashSelected() {
        let urls = Array(selection)
        guard !urls.isEmpty else { return }
        do {
            try FileActionService.trash(items: urls)
            selection.removeAll()
            lastOperationSummary = "Moved \(urls.count) item(s) to Trash"
        } catch {
            lastOperationSummary = error.localizedDescription
        }
        refresh()
    }

    /// Opens the built-in editor for the first selected regular file.
    func editSelected() {
        guard let url = selection.sorted(by: { $0.path < $1.path }).first,
              let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
              values.isDirectory == false, (values.fileSize ?? 0) < 2_000_000 else { return }
        editingURL = url
    }

    func encryptSelected(passphrase: String) {
        guard let url = selection.sorted(by: { $0.path < $1.path }).first else { return }
        do {
            if url.pathExtension == FileActionService.encryptedExtension {
                let output = try FileActionService.decrypt(file: url, passphrase: passphrase)
                lastOperationSummary = "Decrypted \(output.lastPathComponent)"
            } else {
                let output = try FileActionService.encrypt(file: url, passphrase: passphrase)
                lastOperationSummary = "Encrypted \(output.lastPathComponent)"
            }
        } catch {
            lastOperationSummary = error.localizedDescription
        }
        refresh()
    }

    /// Organize assistant: move all loose files here into category folders.
    func organizeFolder() {
        let files = items.filter { !$0.isDirectory }.map(\.url)
        guard !files.isEmpty else { return }
        do {
            let moved = try FileActionService.organize(items: files, in: currentURL)
            let total = moved.values.reduce(0, +)
            lastOperationSummary = "Organized \(total) file(s) into \(moved.count) folder(s)"
        } catch {
            lastOperationSummary = error.localizedDescription
        }
        refresh()
    }

    var organizePlanSummary: [(category: String, count: Int)] {
        FileActionService.organizePlan(items: items.map(\.url))
            .map { (category: $0.key.rawValue, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    func makeDragProvider(for item: FileItem) -> NSItemProvider {
        DragDropSupport.makeFilePromiseProvider(for: item.url)
    }
}
