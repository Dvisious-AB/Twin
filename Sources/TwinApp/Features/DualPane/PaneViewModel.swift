import AppKit
import Foundation
import TwinCore
import TwinPro
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

extension Notification.Name {
    static let twinFilesChanged = Notification.Name("se.dvisious.twin.filesChanged")
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
    @Published var gitBadges: [String: GitStatusService.Badge] = [:]
    @Published var insights: FolderInsightsService.Insights?
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
    private var filesChangedObserver: NSObjectProtocol?

    init(initialPath: URL, bookmarkStore: BookmarkStore = .shared) {
        self.bookmarkStore = bookmarkStore
        // Resolve persisted bookmark at start (FileSystemEngineer requirement).
        let resolved = bookmarkStore.resolveBookmark(for: initialPath) ?? initialPath
        self.currentURL = resolved
        _ = bookmarkStore.startAccessing(resolved)
        refresh()
        filesChangedObserver = NotificationCenter.default.addObserver(
            forName: .twinFilesChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
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
        refreshGitBadges()
        refreshInsights()
    }

    /// Proactive folder analysis (orphans, risks, oversized) off the main thread.
    private func refreshInsights() {
        let folder = currentURL
        Task.detached(priority: .utility) {
            let found = FolderInsightsService.analyze(folder: folder)
            await MainActor.run { [weak self] in
                if self?.currentURL == folder { self?.insights = found }
            }
        }
    }

    /// Builds KARTOTEK.md in the current folder. Returns its path for display.
    @discardableResult
    func buildCatalog() -> String? {
        do {
            let output = try FolderInsightsService.generateCatalog(for: currentURL)
            lastOperationSummary = "Kartotek: \(output.lastPathComponent)"
            refresh()
            return output.path
        } catch {
            lastOperationSummary = error.localizedDescription
            return nil
        }
    }

    /// Moves orphan (loose, long-untouched) files into a Kartotek subfolder.
    func collectOrphans() {
        guard let orphans = insights?.orphanFiles, !orphans.isEmpty else { return }
        let folder = currentURL.appendingPathComponent("Kartotek")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var moved = 0
            for url in orphans {
                let target = folder.appendingPathComponent(url.lastPathComponent)
                if !FileManager.default.fileExists(atPath: target.path) {
                    try TwinCore.fileCoordinator.moveItem(at: url, to: target)
                    moved += 1
                }
            }
            lastOperationSummary = "Collected \(moved) orphan file(s) into Kartotek/"
        } catch {
            lastOperationSummary = error.localizedDescription
        }
        refresh()
    }

    /// Git badges (Pro): computed off the main thread, only when unlocked.
    private func refreshGitBadges() {
        guard ProFeatureGate.shared.isUnlocked else { gitBadges = [:]; return }
        let folder = currentURL
        Task.detached(priority: .utility) {
            let badges = GitStatusService.badges(for: folder)
            await MainActor.run { [weak self] in
                if self?.currentURL == folder { self?.gitBadges = badges }
            }
        }
    }

    func gitBadge(for item: FileItem) -> GitStatusService.Badge? {
        guard ProFeatureGate.shared.isUnlocked else { return nil }
        let badge = gitBadges[item.url.resolvingSymlinksInPath().path]
        return badge?.isDirty == true ? badge : nil
    }

    /// Background directory sizes (cached in DirectorySizeService).
    /// TCC-protected folders are never sized in the background (they
    /// would trigger macOS consent prompts); they show "--".
    private func computeDirectorySizes() {
        let directories = items.filter(\.isDirectory).map(\.url)
            .filter { !DirectorySizeService.isProtectedFolder($0) }
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
            return SizeFormatting.string(forBytes: item.size)
        }
        if let size = directorySizes[item.url.path] {
            return SizeFormatting.string(forBytes: size)
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

    /// Cancellable entry points used by the function bar / F5 / F6.
    private var operationTask: Task<Void, Never>?

    func startCopy(to dest: URL) {
        let urls = Array(selection)
        operationTask = Task { await self.performFileOperation(urls: urls, to: dest, move: false) }
    }

    func startMove(to dest: URL) {
        let urls = Array(selection)
        operationTask = Task { await self.performFileOperation(urls: urls, to: dest, move: true) }
    }

    func cancelOperation() {
        operationTask?.cancel()
    }

    /// Copies/moves into `dest` via TwinCore's shared batch service,
    /// publishing its progress events. No file-loop lives in the UI layer.
    func performFileOperation(urls: [URL], to dest: URL, move: Bool) async {
        guard !urls.isEmpty, !isPerformingOperation else { return }
        isPerformingOperation = true
        operationProgress = 0
        let verb = move ? "Moving" : "Copying"
        operationLabel = urls.count == 1
            ? "\(verb) \(urls[0].lastPathComponent)…"
            : "\(verb) \(urls.count) files…"
        defer {
            isPerformingOperation = false
            operationLabel = nil
            operationProgress = 0
        }
        let startedAt = Date()
        do {
            for try await event in TwinCore.fileCoordinator.batchCopyMove(urls: urls, to: dest, move: move) {
                switch event {
                case .progress(let fraction, let bytesDone, let bytesTotal, let currentItem):
                    operationProgress = fraction
                    if bytesTotal > 0 {
                        let elapsed = max(Date().timeIntervalSince(startedAt), 0.1)
                        let speed = Double(bytesDone) / elapsed
                        operationLabel = "\(verb) \(currentItem) — "
                            + "\(SizeFormatting.string(forBytes: Int64(bytesDone))) of "
                            + "\(SizeFormatting.string(forBytes: Int64(bytesTotal))) · "
                            + "\(SizeFormatting.string(forBytes: Int64(speed)))/s"
                    }
                case .finished(let done, let skipped):
                    lastOperationSummary = skipped > 0
                        ? "\(move ? "Moved" : "Copied") \(done), skipped \(skipped) existing"
                        : nil
                }
            }
        } catch is CancellationError {
            lastOperationSummary = "Operation cancelled"
        } catch {
            lastOperationSummary = error.localizedDescription
        }
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
        // Option held during the drop means move (Finder/TC convention),
        // a plain drop copies. The flag is read from the current event.
        let move = NSApplication.shared.currentEvent?.modifierFlags.contains(.option) ?? false
        await performFileOperation(urls: incoming, to: currentURL, move: move)
        if move {
            NotificationCenter.default.post(name: .twinFilesChanged, object: nil)
        }
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

    func createFolder(named name: String) {
        do {
            let folder = try ArchiveService.createFolder(named: name, in: currentURL)
            lastOperationSummary = "Created \(folder.lastPathComponent)"
            refresh()
            selection = [folder]
        } catch { lastOperationSummary = error.localizedDescription }
    }

    func renameSelected(to newName: String) {
        guard let url = selection.sorted(by: { $0.path < $1.path }).first else { return }
        do {
            let renamed = try ArchiveService.rename(item: url, to: newName)
            lastOperationSummary = "Renamed to \(renamed.lastPathComponent)"
            refresh()
            selection = [renamed]
        } catch { lastOperationSummary = error.localizedDescription }
    }

    var selectedIsArchive: Bool {
        guard let url = selection.sorted(by: { $0.path < $1.path }).first else { return false }
        return ArchiveService.isArchive(url)
    }

    func unpackSelected() {
        guard let url = selection.sorted(by: { $0.path < $1.path }).first else { return }
        do {
            let folder = try ArchiveService.unpack(archive: url)
            lastOperationSummary = "Unpacked to \(folder.lastPathComponent)"
            refresh()
            selection = [folder]
        } catch { lastOperationSummary = error.localizedDescription }
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
