import Foundation

/// Folder Sync (Pro): compares two folders recursively and can make the
/// destination match the source. Safe by default: nothing is deleted
/// unless `deleteExtras` is explicitly on (mirror mode).
public enum FolderSyncService {

    public enum SyncState: String, Sendable, Equatable {
        case onlyInSource
        case onlyInDestination
        case different
        case same
    }

    public struct SyncEntry: Sendable, Equatable, Identifiable {
        public var id: String { relativePath }
        public let relativePath: String
        public let state: SyncState
        public let sourceSize: UInt64?
        public let destinationSize: UInt64?
    }

    private static func inventory(of root: URL) -> [String: (size: UInt64, modified: Date)] {
        // Enumerator URLs resolve symlinks (/var -> /private/var), so the
        // relative path must be computed from canonical paths on both sides.
        let canonicalRoot = root.resolvingSymlinksInPath().path
        var map: [String: (UInt64, Date)] = [:]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: []
        ) else { return map }
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(
                forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
            )
            guard values?.isRegularFile == true else { continue }
            let canonical = url.resolvingSymlinksInPath().path
            guard canonical.hasPrefix(canonicalRoot + "/") else { continue }
            let relative = String(canonical.dropFirst(canonicalRoot.count + 1))
            map[relative] = (
                UInt64(values?.fileSize ?? 0),
                values?.contentModificationDate ?? .distantPast
            )
        }
        return map
    }

    /// Full comparison of two folder trees (files only).
    public static func compare(source: URL, destination: URL) -> [SyncEntry] {
        let sourceMap = inventory(of: source)
        let destinationMap = inventory(of: destination)
        var entries: [SyncEntry] = []
        for path in Set(sourceMap.keys).union(destinationMap.keys).sorted() {
            switch (sourceMap[path], destinationMap[path]) {
            case (.some(let a), .none):
                entries.append(SyncEntry(relativePath: path, state: .onlyInSource, sourceSize: a.size, destinationSize: nil))
            case (.none, .some(let b)):
                entries.append(SyncEntry(relativePath: path, state: .onlyInDestination, sourceSize: nil, destinationSize: b.size))
            case (.some(let a), .some(let b)):
                let same = a.size == b.size
                entries.append(SyncEntry(
                    relativePath: path,
                    state: same ? .same : .different,
                    sourceSize: a.size, destinationSize: b.size
                ))
            case (.none, .none):
                break
            }
        }
        return entries
    }

    public struct SyncResult: Sendable, Equatable {
        public var copied: Int = 0
        public var deleted: Int = 0
        public var skippedSame: Int = 0
    }

    /// Makes destination match source for missing/different files.
    /// Extras in the destination are kept unless `deleteExtras` is true.
    @discardableResult
    public static func sync(
        source: URL,
        destination: URL,
        deleteExtras: Bool = false
    ) throws -> SyncResult {
        let plan = compare(source: source, destination: destination)
        var result = SyncResult()
        var newCopies: [String] = []
        var trashedExtras: [JournalMove] = []
        var overwritten = 0
        for entry in plan {
            let sourceFile = source.appendingPathComponent(entry.relativePath)
            let destinationFile = destination.appendingPathComponent(entry.relativePath)
            switch entry.state {
            case .onlyInSource, .different:
                let existed = FileManager.default.fileExists(atPath: destinationFile.path)
                try FileManager.default.createDirectory(
                    at: destinationFile.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try TwinCore.fileCoordinator.copyItem(at: sourceFile, to: destinationFile)
                if existed { overwritten += 1 } else { newCopies.append(destinationFile.path) }
                result.copied += 1
            case .onlyInDestination:
                if deleteExtras {
                    var resulting: NSURL?
                    try FileManager.default.trashItem(at: destinationFile, resultingItemURL: &resulting)
                    if let resultingURL = resulting as URL? {
                        trashedExtras.append(JournalMove(from: destinationFile, to: resultingURL))
                    }
                    result.deleted += 1
                }
            case .same:
                result.skippedSame += 1
            }
        }
        if result.copied > 0 || result.deleted > 0 {
            var title = "Synced \(source.lastPathComponent) to \(destination.lastPathComponent)"
                + " (\(result.copied) copied, \(result.deleted) removed"
            if overwritten > 0 { title += ", \(overwritten) updated — updates can't be undone" }
            title += ")"
            var record = OperationRecord(kind: .sync, title: title)
            record.created = newCopies
            record.trashed = trashedExtras
            OperationJournal.shared.record(record)
        }
        return result
    }
}
