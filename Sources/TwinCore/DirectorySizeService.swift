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

    public init() {}

    public func cachedSize(for url: URL) -> UInt64? {
        guard let entry = cache[url.path] else { return nil }
        let current = modificationDate(of: url)
        return entry.modified == current ? entry.size : nil
    }

    /// Computes (or returns cached) recursive size. Safe to call repeatedly.
    @discardableResult
    public func size(for url: URL) async -> UInt64 {
        if let cached = cachedSize(for: url) { return cached }
        let modified = modificationDate(of: url)
        let total = Self.computeSize(of: url)
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

    /// Synchronous recursive walk. Call from a background context (actor does).
    public static func computeSize(of url: URL) -> UInt64 {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: keys, options: []
        ) else { return 0 }
        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: Set(keys))
            if values?.isRegularFile == true {
                total += UInt64(values?.fileSize ?? 0)
            }
        }
        return total
    }
}
