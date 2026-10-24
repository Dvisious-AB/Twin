import Foundation

/// Recursive file search — Total Commander's Alt+F7 in Twin terms.
/// Searches names and (optionally) text content under a root folder
/// and returns an actionable result list ("feed to listbox"):
/// callers reveal, open or copy straight from the results.
public enum FileSearchService {
    public struct Query: Sendable, Equatable {
        /// Case-insensitive substring for the file name. Empty = any name.
        public var nameText: String = ""
        /// Case-insensitive text that must occur in the file.
        /// Empty = don't look inside files. Text-like files only.
        public var contentText: String = ""
        public var includeHidden: Bool = false
        public var maxResults: Int = 500
        /// Files larger than this are never content-searched.
        public var maxContentBytes: Int = 5_000_000

        public init() {}
        public var isEmpty: Bool {
            nameText.trimmingCharacters(in: .whitespaces).isEmpty
                && contentText.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    public struct Match: Identifiable, Sendable, Equatable {
        public var id: String { url.path }
        public let url: URL
        public let isDirectory: Bool
        public let size: UInt64
        public let modified: Date
        /// The first line containing the content hit, when searched.
        public let snippet: String?

        public init(url: URL, isDirectory: Bool, size: UInt64, modified: Date, snippet: String?) {
            self.url = url
            self.isDirectory = isDirectory
            self.size = size
            self.modified = modified
            self.snippet = snippet
        }
    }

    public struct Outcome: Sendable {
        public let matches: [Match]
        public let scannedCount: Int
        public let truncated: Bool
    }

    /// Synchronous core — call it from a background task (the app
    /// uses Task.detached). Checks Task cancellation regularly.
    /// `progress` reports scanned counts.
    public static func search(
        in root: URL,
        query: Query,
        progress: @Sendable (Int) -> Void = { _ in }
    ) -> Outcome {
        let nameNeedle = query.nameText.trimmingCharacters(in: .whitespaces).lowercased()
        let contentNeedle = query.contentText.trimmingCharacters(in: .whitespaces).lowercased()
        var matches: [Match] = []
        var scanned = 0
        var truncated = false

        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if !query.includeHidden { options.insert(.skipsHiddenFiles) }
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: options
        ) else {
            return Outcome(matches: [], scannedCount: 0, truncated: false)
        }

        for case let url as URL in enumerator {
            if scanned % 200 == 0 {
                progress(scanned)
                if Task.isCancelled { break }
            }
            scanned += 1
            let values = try? url.resourceValues(
                forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            let isDirectory = values?.isDirectory ?? false

            if !nameNeedle.isEmpty,
               !url.lastPathComponent.lowercased().contains(nameNeedle) {
                continue
            }
            var snippet: String?
            if !contentNeedle.isEmpty {
                guard !isDirectory,
                      FileTypeRegistry.kind(for: url).isTextEditable,
                      (values?.fileSize ?? .max) <= query.maxContentBytes,
                      let text = try? String(contentsOf: url, encoding: .utf8),
                      let hit = text.components(separatedBy: "\n")
                        .first(where: { $0.lowercased().contains(contentNeedle) })
                else { continue }
                snippet = hit.trimmingCharacters(in: .whitespaces)
            }
            matches.append(Match(
                url: url,
                isDirectory: isDirectory,
                size: UInt64(values?.fileSize ?? 0),
                modified: values?.contentModificationDate ?? .distantPast,
                snippet: snippet))
            if matches.count >= query.maxResults {
                truncated = true
                break
            }
        }
        progress(scanned)
        return Outcome(matches: matches, scannedCount: scanned, truncated: truncated)
    }
}
