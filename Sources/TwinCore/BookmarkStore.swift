import Foundation

/// Persists security-scoped bookmarks in `UserDefaults`.
///
/// Bookmarks are stored as `[path: bookmarkData]` under a versioned key.
/// On launch, `resolveAll()` re-resolves every bookmark, refreshes stale
/// data, and starts security-scoped access so sandboxed panes can read
/// folders the user granted access to in a previous session.
public final class BookmarkStore: @unchecked Sendable {

    public static let shared = BookmarkStore()

    public static let defaultsKey = "se.dvisious.twin.bookmarks.v1"

    private let defaults: UserDefaults
    private let key: String
    private let lock = NSLock()
    private var accessedURLs: [String: URL] = [:]

    public init(defaults: UserDefaults = .standard, key: String = BookmarkStore.defaultsKey) {
        self.defaults = defaults
        self.key = key
    }

    // MARK: - Raw storage

    private func loadStore() -> [String: Data] {
        // UserDefaults dictionary access is thread-safe; lock only guards accessedURLs mutation pairing.
        defaults.dictionary(forKey: key) as? [String: Data] ?? [:]
    }

    private func saveStore(_ store: [String: Data]) {
        defaults.set(store, forKey: key)
    }

    // MARK: - Save

    /// Creates a security-scoped bookmark for `url` and persists it.
    /// Returns the bookmark data, or `nil` if creation failed.
    @discardableResult
    public func saveBookmark(for url: URL) -> Data? {
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return nil }

        var store = loadStore()
        store[url.path] = data
        saveStore(store)
        return data
    }

    /// Removes the bookmark for `url` and stops accessing it.
    public func removeBookmark(for url: URL) {
        removeBookmark(forPath: url.path)
    }

    public func removeBookmark(forPath path: String) {
        var store = loadStore()
        store.removeValue(forKey: path)
        saveStore(store)

        lock.lock()
        if let accessed = accessedURLs.removeValue(forKey: path) {
            accessed.stopAccessingSecurityScopedResource()
        }
        lock.unlock()
    }

    public func removeAll() {
        stopAccessingAll()
        saveStore([:])
    }

    // MARK: - Resolve

    /// Resolves the persisted bookmark for `url`'s path, if any.
    /// Refreshes stale bookmarks in place.
    public func resolveBookmark(for url: URL) -> URL? {
        resolveBookmark(forPath: url.path)
    }

    public func resolveBookmark(forPath path: String) -> URL? {
        let store = loadStore()
        guard let data = store[path] else { return nil }
        return resolve(data: data, forPath: path)
    }

    /// Resolves every persisted bookmark. Call at app start.
    /// Stale bookmarks are refreshed; unresolvable ones are dropped.
    @discardableResult
    public func resolveAll() -> [URL] {
        let store = loadStore()
        var resolved: [URL] = []
        var validPaths = Set<String>()

        for (path, data) in store {
            if let url = resolve(data: data, forPath: path) {
                resolved.append(url)
                validPaths.insert(path)
            }
        }

        if validPaths.count != store.count {
            var pruned = store
            for path in store.keys where !validPaths.contains(path) {
                pruned.removeValue(forKey: path)
            }
            saveStore(pruned)
        }

        return resolved.sorted { $0.path < $1.path }
    }

    private func resolve(data: Data, forPath path: String) -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        if isStale {
            _ = saveBookmark(for: url)
        }
        return url
    }

    // MARK: - Security-scoped access

    /// Resolves and starts security-scoped access for `url` if a bookmark exists.
    /// Returns the resolved URL (or `url` itself if no bookmark is stored).
    @discardableResult
    public func startAccessing(_ url: URL) -> URL {
        let resolved = resolveBookmark(for: url) ?? url

        lock.lock()
        defer { lock.unlock() }
        if accessedURLs[resolved.path] == nil {
            if resolved.startAccessingSecurityScopedResource() {
                accessedURLs[resolved.path] = resolved
            }
        }
        return resolved
    }

    /// Starts access for all persisted bookmarks. Call at app start.
    @discardableResult
    public func startAccessingAll() -> [URL] {
        resolveAll().map { startAccessing($0) }
    }

    public func stopAccessing(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }
        if let accessed = accessedURLs.removeValue(forKey: url.path) {
            accessed.stopAccessingSecurityScopedResource()
        }
    }

    public func stopAccessingAll() {
        lock.lock()
        defer { lock.unlock() }
        for url in accessedURLs.values {
            url.stopAccessingSecurityScopedResource()
        }
        accessedURLs.removeAll()
    }

    // MARK: - Introspection

    public var bookmarkedPaths: [String] {
        loadStore().keys.sorted()
    }

    public func hasBookmark(for url: URL) -> Bool {
        loadStore()[url.path] != nil
    }
}
