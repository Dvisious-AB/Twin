import Foundation

/// Archive and naming operations: unpack, new folder, rename.
/// Kept separate from FileActionService (pack/MD5/crypto/trash).
public enum ArchiveService {

    public enum ArchiveError: Error, LocalizedError, Sendable {
        case emptyName
        case alreadyExists(String)
        case failed(String)

        public var errorDescription: String? {
            switch self {
            case .emptyName: return "Name can't be empty"
            case .alreadyExists(let name): return "\(name) already exists"
            case .failed(let message): return message
            }
        }
    }

    private static func validatedName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("/") else { throw ArchiveError.emptyName }
        return trimmed
    }

    // MARK: - New folder (F7)

    @discardableResult
    public static func createFolder(named name: String, in directory: URL) throws -> URL {
        let folderName = try validatedName(name)
        let folder = directory.appendingPathComponent(folderName)
        guard !FileManager.default.fileExists(atPath: folder.path) else {
            throw ArchiveError.alreadyExists(folderName)
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        var record = OperationRecord(kind: .createFolder, title: "Created folder \(folderName)")
        record.created = [folder.path]
        OperationJournal.shared.record(record)
        return folder
    }

    // MARK: - Rename (Shift+F6)

    @discardableResult
    public static func rename(item: URL, to newName: String) throws -> URL {
        let name = try validatedName(newName)
        let target = item.deletingLastPathComponent().appendingPathComponent(name)
        guard target != item else { return item }
        guard !FileManager.default.fileExists(atPath: target.path) else {
            throw ArchiveError.alreadyExists(name)
        }
        try TwinCore.fileCoordinator.moveItem(at: item, to: target)
        var record = OperationRecord(
            kind: .rename, title: "Renamed \(item.lastPathComponent) to \(name)")
        record.moves = [JournalMove(from: item, to: target)]
        OperationJournal.shared.record(record)
        return target
    }

    // MARK: - Unpack (Alt+F6)

    /// Unpacks a zip into `<archive-name>/` next to the archive.
    @discardableResult
    public static func unpack(archive: URL) throws -> URL {
        let folderName = archive.deletingPathExtension().lastPathComponent
        var folder = archive.deletingLastPathComponent().appendingPathComponent(folderName)
        var counter = 1
        while FileManager.default.fileExists(atPath: folder.path) {
            counter += 1
            folder = archive.deletingLastPathComponent().appendingPathComponent("\(folderName) \(counter)")
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archive.path, folder.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ArchiveError.failed("Unpack failed (ditto exit \(process.terminationStatus))")
        }
        var record = OperationRecord(kind: .unpack, title: "Unpacked \(archive.lastPathComponent)")
        record.created = [folder.path]
        OperationJournal.shared.record(record)
        return folder
    }

    public static func isArchive(_ url: URL) -> Bool {
        ["zip"].contains(url.pathExtension.lowercased())
    }
}
