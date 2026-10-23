import Foundation

/// Recursive directory sizes with a cache — Total Commander shows `<DIR>`
/// until Space / Alt+Shift+Enter asks for sizes; Twin computes in the
/// background and caches, invalidated by the directory's modification date.
public actor DirectorySizeService {
    public static let shared = DirectorySizeService()

    private struct Entry {
        let size: UInt64
        let modified: Date
    }

    private var cache: [String: Entry] = [:]

    /// Limits concurrent recursive walks. Without a gate, listing a
    /// home folder queued dozens of walks on this actor, which ran
    /// them strictly one-by-one — large trees (docker, model caches)
    /// blocked every other folder's size for minutes (issue #17).
    private let gate = ConcurrencyGate(limit: 4)

    /// Standard home folders macOS guards with TCC consent prompts.
    /// Background size computation must never walk into them unasked:
    /// the user would get a permission prompt for a folder they never
    /// opened (observed live: Music, Desktop, Photos prompts while
    /// merely listing the home folder).
    public static let protectedFolderNames: Set<String> = [
        "Desktop", "Documents", "Downloads", "Pictures", "Movies", "Music", "Library"
    ]

    /// True when `url` is exactly `/Users/<user>/<protected folder>`.
    /// Descendants are not protected by this check: once the user has
    /// explicitly opened such a folder, sizing its children is fine.
    public static func isProtectedFolder(_ url: URL) -> Bool {
        let components = url.standardizedFileURL.pathComponents
        guard components.count == 4, components[1] == "Users" else { return false }
        return protectedFolderNames.contains(components[3])
    }

    public init() {}

    public func cachedSize(for url: URL) -> UInt64? {
        guard let entry = cache[url.path] else { return nil }
        let current = modificationDate(of: url)
        return entry.modified == current ? entry.size : nil
    }

    /// Computes (or returns cached) recursive size. Safe to call repeatedly.
    /// Protected folders (see `isProtectedFolder`) are only walked when
    /// `explicit` is true, i.e. the user asked for that folder's size.
    @discardableResult
    public func size(for url: URL, explicit: Bool = false) async -> UInt64 {
        if !explicit, Self.isProtectedFolder(url) { return 0 }
        if let cached = cachedSize(for: url) { return cached }
        let modified = modificationDate(of: url)
        await gate.acquire()
        // The walk runs detached so this actor stays responsive and up
        // to the gate limit of walks proceed in parallel.
        let total = await Task.detached(priority: .utility) {
            Self.computeSize(of: url)
        }.value
        await gate.release()
        cache[url.path] = Entry(size: total, modified: modified)
        return total
    }

    public func invalidate(for url: URL) {
        cache.removeValue(forKey: url.path)
    }

    public func invalidateAll() {
        cache.removeAll()
    }

    private func modificationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
    }

    /// Synchronous recursive walk. Call from a background context.
    /// Protected subfolders below the walk root are pruned, so sizing a
    /// home folder never triggers TCC prompts; their bytes are excluded.
    /// Hidden files are skipped: they are mostly caches and VCS data,
    /// and including them made large trees dramatically slower (#17).
    public static func computeSize(of url: URL) -> UInt64 {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true, isProtectedFolder(fileURL) {
                enumerator.skipDescendants()
            } else if values?.isRegularFile == true {
                total += UInt64(values?.fileSize ?? 0)
            }
        }
        return total
    }
}

/// FIFO counting semaphore for limiting concurrent background walks.
private actor ConcurrencyGate {
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        available = limit
    }

    func acquire() async {
        if available > 0 {
            available -= 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if waiters.isEmpty {
            available += 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}
