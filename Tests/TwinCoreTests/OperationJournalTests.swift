import Foundation
import XCTest
@testable import TwinCore

/// Undo system: every operation lands in the journal, and undo
/// rewinds it — organize included (the user's example).
final class OperationJournalTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("TwinJournalTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeFile(_ name: String, in dir: URL? = nil) throws -> URL {
        let url = (dir ?? root).appendingPathComponent(name)
        try "content of \(name)".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func latestEntry(titled prefix: String) -> OperationRecord? {
        OperationJournal.shared.entries.last { $0.title.hasPrefix(prefix) }
    }

    func testOrganizeIsJournaledAndUndoRestoresFiles() throws {
        let jpg = try makeFile("photo.jpg")
        let pdf = try makeFile("report.pdf")
        let mp3 = try makeFile("song.mp3")

        _ = try FileActionService.organize(items: [jpg, pdf, mp3], in: root)
        XCTAssertFalse(FileManager.default.fileExists(atPath: jpg.path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Images/photo.jpg").path))

        let entry = try XCTUnwrap(latestEntry(titled: "Organized 3 file(s)"))
        XCTAssertEqual(entry.kind, .organize)
        XCTAssertEqual(entry.moves.count, 3)
        XCTAssertEqual(Set(entry.createdFolders.map { URL(fileURLWithPath: $0).lastPathComponent }),
                       ["Images", "Documents", "Audio"])

        let report = OperationJournal.shared.undo(entry)
        XCTAssertTrue(report.failures.isEmpty, report.summary)
        XCTAssertTrue(report.fullyUndone)
        for file in [jpg, pdf, mp3] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), file.lastPathComponent)
        }
        // Category folders created by the run are gone again.
        for folder in ["Images", "Documents", "Audio"] {
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: root.appendingPathComponent(folder).path), folder)
        }
        // And redo organizes again.
        let undone = try XCTUnwrap(latestEntry(titled: "Organized 3 file(s)"))
        XCTAssertTrue(undone.undone)
        let redoReport = OperationJournal.shared.redo(undone)
        XCTAssertTrue(redoReport.failures.isEmpty, redoReport.summary)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Images/photo.jpg").path))
    }

    func testTrashUndoBringsFileHome() throws {
        let file = try makeFile("keepme.txt")
        try FileActionService.trash(items: [file])
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))

        let entry = try XCTUnwrap(latestEntry(titled: "Moved 1 item(s) to Trash"))
        let report = OperationJournal.shared.undo(entry)
        XCTAssertTrue(report.fullyUndone, report.summary)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testUndoBlockedByOccupiedHomeRetriesRemainder() throws {
        let file = try makeFile("blocked.txt")
        try FileActionService.trash(items: [file])
        // A new file takes the original place.
        _ = try makeFile("blocked.txt")

        let entry = try XCTUnwrap(latestEntry(titled: "Moved 1 item(s) to Trash"))
        let first = OperationJournal.shared.undo(entry)
        XCTAssertFalse(first.fullyUndone)
        XCTAssertEqual(first.failures.count, 1)

        // Remove the blocker — retry finishes exactly the remainder.
        try FileManager.default.removeItem(at: file)
        let stillPending = try XCTUnwrap(latestEntry(titled: "Moved 1 item(s) to Trash"))
        XCTAssertFalse(stillPending.undone)
        let second = OperationJournal.shared.undo(stillPending)
        XCTAssertTrue(second.fullyUndone, second.summary)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testRenameAndBatchRenameUndo() throws {
        let file = try makeFile("old name.txt")
        _ = try ArchiveService.rename(item: file, to: "new name.txt")
        let renameEntry = try XCTUnwrap(latestEntry(titled: "Renamed old name.txt"))
        _ = OperationJournal.shared.undo(renameEntry)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))

        let a = try makeFile("img one.png")
        let b = try makeFile("img two.png")
        var rule = FileActionService.BatchRenameRule()
        rule.find = "img"
        rule.replace = "photo"
        _ = try FileActionService.batchRename(items: [a, b], rule: rule)
        let batchEntry = try XCTUnwrap(latestEntry(titled: "Batch renamed 2 file(s)"))
        XCTAssertEqual(batchEntry.moves.count, 2)
        _ = OperationJournal.shared.undo(batchEntry)
        XCTAssertTrue(FileManager.default.fileExists(atPath: a.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: b.path))
    }

    func testCreateFolderUndoSendsItToTrash() throws {
        let folder = try ArchiveService.createFolder(named: "TempFolder", in: root)
        let entry = try XCTUnwrap(latestEntry(titled: "Created folder TempFolder"))
        let report = OperationJournal.shared.undo(entry)
        XCTAssertTrue(report.fullyUndone, report.summary)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }

    func testJournalPersistsAcrossInstances() throws {
        let journalDir = root.appendingPathComponent("journal-home")
        let first = OperationJournal(directory: journalDir)
        var record = OperationRecord(kind: .rename, title: "Renamed a.txt to b.txt")
        record.moves = [JournalMove(from: "/tmp/a.txt", to: "/tmp/b.txt")]
        first.record(record)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.journalFileURL.path))

        let second = OperationJournal(directory: journalDir)
        XCTAssertEqual(second.entries.count, 1)
        XCTAssertEqual(second.entries.first?.title, "Renamed a.txt to b.txt")
        XCTAssertTrue(second.canUndo)
    }
}
