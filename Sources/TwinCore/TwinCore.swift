import Foundation
public struct TwinCore {
  public static func saveBookmark(for url: URL) -> Data? { try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) }
  public static func resolveBookmark(_ data: Data) -> URL? { var s=false; return try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &s) }
}
