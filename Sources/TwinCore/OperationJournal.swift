import Foundation

/// One file that changed place: `from` is where it was, `to` where
/// the operation put it. Paths (not URLs) so the journal is plain
/// JSON the user can read — the "tail" of everything Twin has done.
public struct JournalMove: Codable, Sendable, Equatable {
    public var from: String
    public var to: String
    /// True once undo has put this item back. Kept in the record so
    /// redo knows exactly what to re-apply, and a retried undo only
    /// attempts the moves that are still pending.
    public var reverted: Bool = false
    public init(from: String, to: String) {
        self.from = from
        self.to = to
    }
    public init(from: URL, to: URL) {
        self.init(from: from.path, to: to.path)
    }
}

/// A journaled operation that can be undone (and usually redone).
public struct OperationRecord: Codable, Identifiable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable {
        case copy, move, rename, batchRename, organize
        case trash, createFolder, createFile, unpack, sync
    }

    public var id: UUID
    public var date: Date
    public var kind: Kind
    /// Human summary, e.g. "Organized 12 files in Downloads".
    public var title: String
    /// Forward moves (copy keeps the source in place — undoing a
    /// copy trashes the copies at `to`).
    public var moves: [JournalMove] = []
    /// Files/folders the operation created. Undo sends them to Trash.
    public var created: [String] = []
    /// Empty container folders the operation created (e.g. organize
    /// categories). Undo removes them when empty, after moves back.
    public var createdFolders: [String] = []
    /// Items sent to Trash: original location -> location in Trash.
    public var trashed: [JournalMove] = []
    /// False when undo cannot restore the prior state (e.g. a sync
    /// that overwrote files). The entry still documents what happened.
    public var undoable: Bool = true
    public var undone: Bool = false

    public init(kind: Kind, title: String) {
        self.id = UUID()
        self.date = Date()
        self.kind = kind
        self.title = title
    }

    public var itemCount: Int { moves.count + created.count + trashed.count }

    /// Creations (zip, folder, unpack…) can't be redone — the file
    /// was made by an action, not moved. Everything else can.
    public var redoable: Bool {
        undoable && kind != .createFile && kind != .createFolder && kind != .unpack
    }

    public var symbolName: String {
        switch kind {
        case .copy: return "doc.on.doc"
        case .move: return "arrow.right.doc.on.clipboard"
        case .rename, .batchRename: return "pencil"
        case .organize: return "folder.badge.gearshape"
        case .trash: return "trash"
        case .createFolder: return "folder.badge.plus"
        case .createFile: return "doc.badge.plus"
        case .unpack: return "archivebox"
        case .sync: return "arrow.triangle.2.circlepath"
        }
    }
}

/// Outcome of an undo/redo attempt. Partial success is reported, not
/// hidden: the record keeps only the moves that are still pending,
/// so pressing Undo again retries exactly the remainder.
public struct UndoReport: Sendable, Equatable {
    public var title: String
    public var succeeded: Int = 0
    public var failures: [String] = []
    public var fullyUndone: Bool = false

    public var summary: String {
        if failures.isEmpty {
            return "Undid: \(title)"
        }
        return "Partly undid \(title) — \(failures.count) item(s) failed: "
            + failures.prefix(2).joined(separator: "; ")
    }
}

/// Persistent log of every file operation Twin performs — the tail
/// the user can inspect (History) and rewind (Cmd+Z). Stored as JSON
/// in Application Support/Twin/operation-journal.json, capped at
/// 200 entries. Undo never journals itself (no undo-of-undo loops);
/// Redo re-applies the forward moves.
public final class OperationJournal: ObservableObject, @unchecked Sendable {
    public static let shared = OperationJournal()

    @Published public private(set) var entries: [OperationRecord] = []

    private let fileURL: URL
    private let lock = NSLock()
    private let maxEntries = 200

    public init(directory: URL? = nil) {
        if let directory {
            self.fileURL = directory.appendingPathComponent("operation-journal.json")
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = base.appendingPathComponent("Twin", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("operation-journal.json")
        }
        load()
    }

    public var journalFileURL: URL { fileURL }

    // MARK: - Recording

    /// Appends an operation. Empty operations are ignored.
    public func record(_ record: OperationRecord) {
        guard record.itemCount > 0 || !record.createdFolders.isEmpty else { return }
        lock.lock()
        entries.append(record)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        persistLocked()
        lock.unlock()
        publish()
        DebugLog.shared.info("journal.record", record.title, context: [
            "kind": record.kind.rawValue, "items": String(record.itemCount)
        ])
    }

    public func clear() {
        lock.lock()
        entries = []
        persistLocked()
        lock.unlock()
        publish()
    }

    // MARK: - Undo / redo state

    public var canUndo: Bool { entries.contains { !$0.undone && $0.undoable } }
    public var canRedo: Bool { entries.contains { $0.undone && $0.redoable } }

    public var nextUndoTitle: String? { entries.last { !$0.undone && $0.undoable }?.title }
    public var nextRedoTitle: String? { entries.last { $0.undone && $0.redoable }?.title }

    // MARK: - Undo

    @discardableResult
    public func undoLatest() -> UndoReport? {
        guard let record = entries.last(where: { !$0.undone && $0.undoable }) else { return nil }
        return undo(record)
    }

    @discardableResult
    public func redoLatest() -> UndoReport? {
        guard let record = entries.last(where: { $0.undone && $0.redoable }) else { return nil }
        return redo(record)
    }

    /// Reverses one record. Moves go back, created files go to Trash,
    /// trashed items come home. Partial failures stay in the record
    /// so a retry only redoes the remainder.
    @discardableResult
    public func undo(_ record: OperationRecord) -> UndoReport {
        lock.lock()
        defer { lock.unlock() }
        guard let index = entries.firstIndex(where: { $0.id == record.id }) else {
            return UndoReport(title: record.title, failures: ["Entry no longer in the journal"])
        }
        var working = entries[index]
        var report = UndoReport(title: working.title)
        guard !working.undone, working.undoable else {
            report.failures = ["This operation can't be undone"]
            return report
        }
        let fm = FileManager.default

        // 1. Restore trashed items home.
        for index in working.trashed.indices where !working.trashed[index].reverted {
            let pair = working.trashed[index]
            let trashItem = URL(fileURLWithPath: pair.to)
            let home = URL(fileURLWithPath: pair.from)
            guard fm.fileExists(atPath: pair.to) else {
                report.failures.append("\(trashItem.lastPathComponent) is no longer in Trash")
                continue
            }
            guard !fm.fileExists(atPath: pair.from) else {
                report.failures.append("\(home.lastPathComponent) already exists at home")
                continue
            }
            do {
                try fm.createDirectory(at: home.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.moveItem(at: trashItem, to: home)
                working.trashed[index].reverted = true
                report.succeeded += 1
            } catch {
                report.failures.append("\(trashItem.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // 2. Reverse moves — or, for copies, trash the copies.
        for index in working.moves.indices.reversed() where !working.moves[index].reverted {
            let pair = working.moves[index]
            let current = URL(fileURLWithPath: pair.to)
            let original = URL(fileURLWithPath: pair.from)
            guard fm.fileExists(atPath: pair.to) else {
                report.failures.append("\(current.lastPathComponent) no longer exists")
                continue
            }
            do {
                if working.kind == .copy {
                    try fm.trashItem(at: current, resultingItemURL: nil)
                } else {
                    guard !fm.fileExists(atPath: pair.from) else {
                        report.failures.append("\(original.lastPathComponent) already exists")
                        continue
                    }
                    try fm.createDirectory(at: original.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try fm.moveItem(at: current, to: original)
                }
                working.moves[index].reverted = true
                report.succeeded += 1
            } catch {
                report.failures.append("\(current.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // 3. Trash what the operation created (zips, folders, outputs).
        working.created = working.created.filter { path in
            guard fm.fileExists(atPath: path) else { return false }
            do {
                try fm.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                report.succeeded += 1
                return false
            } catch {
                report.failures.append("\(URL(fileURLWithPath: path).lastPathComponent): \(error.localizedDescription)")
                return true
            }
        }

        // 4. Remove container folders the operation created, if empty.
        for folder in working.createdFolders where isEmptyDirectory(folder) {
            try? fm.removeItem(at: URL(fileURLWithPath: folder))
        }
        working.createdFolders = working.createdFolders.filter { fm.fileExists(atPath: $0) }

        report.fullyUndone = working.moves.allSatisfy(\.reverted)
            && working.created.isEmpty && working.trashed.allSatisfy(\.reverted)
        if report.fullyUndone { working.undone = true }
        entries[index] = working
        persistLocked()
        publish()
        DebugLog.shared.info("journal.undo", report.summary, context: ["kind": working.kind.rawValue])
        return report
    }

    /// Re-applies an undone record (move-like and trash operations).
    @discardableResult
    public func redo(_ record: OperationRecord) -> UndoReport {
        lock.lock()
        defer { lock.unlock() }
        guard let index = entries.firstIndex(where: { $0.id == record.id }) else {
            return UndoReport(title: record.title, failures: ["Entry no longer in the journal"])
        }
        var working = entries[index]
        var report = UndoReport(title: working.title)
        guard working.undone, working.undoable else {
            report.failures = ["Nothing to redo"]
            return report
        }
        guard working.kind != .createFile, working.kind != .createFolder, working.kind != .unpack else {
            report.failures = ["Created files can't be redone — run the action again"]
            return report
        }
        let fm = FileManager.default

        // Re-trash what undo brought home.
        for index in working.trashed.indices where working.trashed[index].reverted {
            let pair = working.trashed[index]
            let home = URL(fileURLWithPath: pair.from)
            guard fm.fileExists(atPath: pair.from) else {
                report.failures.append("\(home.lastPathComponent) no longer exists")
                continue
            }
            do {
                var resulting: NSURL?
                try fm.trashItem(at: home, resultingItemURL: &resulting)
                if let resultingURL = resulting as URL? {
                    working.trashed[index].to = resultingURL.path
                }
                working.trashed[index].reverted = false
                report.succeeded += 1
            } catch {
                report.failures.append("\(home.lastPathComponent): \(error.localizedDescription)")
            }
        }
        // Re-apply forward moves.
        for index in working.moves.indices where working.moves[index].reverted {
            let pair = working.moves[index]
            let from = URL(fileURLWithPath: pair.from)
            let to = URL(fileURLWithPath: pair.to)
            guard fm.fileExists(atPath: pair.from), !fm.fileExists(atPath: pair.to) else {
                report.failures.append("\(from.lastPathComponent) can't be moved again")
                continue
            }
            do {
                try fm.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
                if working.kind == .copy {
                    try fm.copyItem(at: from, to: to)
                } else {
                    try fm.moveItem(at: from, to: to)
                }
                working.moves[index].reverted = false
                report.succeeded += 1
            } catch {
                report.failures.append("\(from.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if report.failures.isEmpty {
            working.undone = false
            report.fullyUndone = false
        }
        entries[index] = working
        persistLocked()
        publish()
        DebugLog.shared.info("journal.redo", report.summary, context: ["kind": working.kind.rawValue])
        return report
    }

    // MARK: - Persistence

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([OperationRecord].self, from: data) else { return }
        entries = decoded
    }

    private func persistLocked() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    private func publish() {
        if Thread.isMainThread {
            objectWillChange.send()
        } else {
            DispatchQueue.main.async { [weak self] in self?.objectWillChange.send() }
        }
    }

    private func isEmptyDirectory(_ path: String) -> Bool {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
        return contents.allSatisfy { $0 == ".DS_Store" }
    }
}
