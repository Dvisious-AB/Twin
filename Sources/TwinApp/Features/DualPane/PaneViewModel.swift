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

    var breadcrumbs: [Breadcrumb] {
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
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: currentURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            items = []
            return
        }
        items = contents.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            return FileItem(
                url: url,
                name: url.lastPathComponent,
                isDirectory: values?.isDirectory ?? false,
                size: UInt64(values?.fileSize ?? 0)
            )
        }
        .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    func navigate(to url: URL) {
        // Persist a security-scoped bookmark for the folder we enter,
        // and start accessing it so the sandbox keeps access across launches.
        bookmarkStore.saveBookmark(for: url)
        let resolved = bookmarkStore.startAccessing(url)
        currentURL = resolved
        selection.removeAll()
        refresh()
    }

    func goUp() {
        let parent = currentURL.deletingLastPathComponent()
        guard parent.path != currentURL.path else { return }
        currentURL = parent
        selection.removeAll()
        refresh()
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
        for (index, url) in urls.enumerated() {
            // Yield so SwiftUI can render the progress update.
            await Task.yield()
            let target = dest.appendingPathComponent(url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: target.path) {
                    try FileManager.default.removeItem(at: target)
                }
                if move {
                    try FileManager.default.moveItem(at: url, to: target)
                } else {
                    try FileManager.default.copyItem(at: url, to: target)
                }
            } catch {
                // Keep going for remaining items; progress still advances.
                continue
            }
            operationProgress = Double(index + 1) / total
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
        await performFileOperation(urls: incoming, to: currentURL, move: false)
        return true
    }

    func makeDragProvider(for item: FileItem) -> NSItemProvider {
        DragDropSupport.makeFilePromiseProvider(for: item.url)
    }
}
