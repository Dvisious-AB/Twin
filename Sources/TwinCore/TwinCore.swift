import Foundation

/// Namespace for Twin's core file-system helpers.
///
/// Bookmark persistence lives in `BookmarkStore`; these statics are kept
/// for call-site convenience and backward compatibility.
public enum TwinCore {

    public static var bookmarkStore: BookmarkStore { .shared }

    // MARK: - Bookmarks (persisted)

    /// Creates a security-scoped bookmark for `url` and persists it in UserDefaults.
    @discardableResult
    public static func saveBookmark(for url: URL) -> Data? {
        BookmarkStore.shared.saveBookmark(for: url)
    }

    /// Resolves previously persisted bookmark data (one-off, not from the store).
    public static func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        return try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    /// Resolves the persisted bookmark for `url`, if one exists.
    public static func resolvePersistedBookmark(for url: URL) -> URL? {
        BookmarkStore.shared.resolveBookmark(for: url)
    }

    /// Resolves all persisted bookmarks. Call at app start.
    @discardableResult
    public static func resolveAllBookmarks() -> [URL] {
        BookmarkStore.shared.resolveAll()
    }

    /// Resolves all bookmarks and starts security-scoped access. Call at app start.
    @discardableResult
    public static func restoreBookmarkedAccess() -> [URL] {
        BookmarkStore.shared.startAccessingAll()
    }
}
