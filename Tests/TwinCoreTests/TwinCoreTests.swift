import Foundation
import XCTest
@testable import TwinCore

final class TwinCoreTests: XCTestCase {

    // DirectoryLoadState: empty vs loaded vs errors a user can act on.
    func testEmptyAndLoadedStates() {
        let url = URL(fileURLWithPath: "/tmp")
        XCTAssertEqual(DirectoryLoadState.state(contents: [], for: url), .empty)
        XCTAssertEqual(DirectoryLoadState.state(contents: [url], for: url), .loaded(itemCount: 1))
        XCTAssertFalse(DirectoryLoadState.empty.isError)
    }

    func testPermissionDeniedClassification() {
        let url = URL(fileURLWithPath: "/private/secret")
        let cocoa = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)
        XCTAssertEqual(DirectoryLoadState.classify(error: cocoa, for: url), .permissionDenied(path: url.path))

        let posix = NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))
        XCTAssertEqual(DirectoryLoadState.classify(error: posix, for: url), .permissionDenied(path: url.path))
    }

    func testMissingVolumeClassification() {
        let url = URL(fileURLWithPath: "/Volumes/GoneDisk/photos")
        XCTAssertEqual(DirectoryLoadState.missingState(for: url), .volumeUnavailable(path: url.path))

        let local = URL(fileURLWithPath: "/tmp/definitely-missing-\(UUID().uuidString)")
        XCTAssertEqual(DirectoryLoadState.missingState(for: local), .notFound(path: local.path))
    }

    // BookmarkStore: persists to the injected UserDefaults, resolves, removes.
    func testBookmarkStoreRoundTrip() throws {
        let suite = "TwinCoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = BookmarkStore(defaults: defaults, key: "test.bookmarks")

        let dir = FileManager.default.temporaryDirectory
        XCTAssertFalse(store.hasBookmark(for: dir))
        XCTAssertNotNil(store.saveBookmark(for: dir))
        XCTAssertTrue(store.hasBookmark(for: dir))
        XCTAssertEqual(store.resolveBookmark(for: dir)?.resolvingSymlinksInPath().path, dir.resolvingSymlinksInPath().path)

        store.removeBookmark(for: dir)
        XCTAssertFalse(store.hasBookmark(for: dir))
    }

    // FileActionService: MD5 of "abc" is the well-known RFC 1321 value.
    func testMD5AndChecksumFile() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let file = base.appendingPathComponent("abc.txt")
        try Data("abc".utf8).write(to: file)

        XCTAssertEqual(try FileActionService.md5Hex(of: file), "900150983cd24fb0d6963f7d28e17f72")
        let checksum = try FileActionService.createMD5File(for: file)
        XCTAssertTrue(FileManager.default.fileExists(atPath: checksum.path))
        XCTAssertTrue(try String(contentsOf: checksum, encoding: .utf8).hasPrefix("900150983cd24fb0d6963f7d28e17f72"))
    }

    func testEncryptDecryptRoundTrip() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let file = base.appendingPathComponent("secret.txt")
        try "hemligt".write(to: file, atomically: true, encoding: .utf8)

        let encrypted = try FileActionService.encrypt(file: file, passphrase: "losen")
        XCTAssertEqual(encrypted.pathExtension, "twinenc")
        XCTAssertNotEqual(try Data(contentsOf: encrypted), Data("hemligt".utf8))

        let restored = base.appendingPathComponent("restored.txt")
        try? FileManager.default.removeItem(at: file)
        let decrypted = try FileActionService.decrypt(file: encrypted, passphrase: "losen")
        XCTAssertEqual(decrypted.path, restored.path.replacingOccurrences(of: "restored", with: "secret"))
        XCTAssertEqual(try String(contentsOf: decrypted, encoding: .utf8), "hemligt")

        XCTAssertThrowsError(try FileActionService.decrypt(file: encrypted, passphrase: "fel"))
    }

    func testDirectorySizeAndCompress() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sub = base.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        try String(repeating: "x", count: 100).write(to: sub.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try String(repeating: "y", count: 50).write(to: base.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)

        XCTAssertEqual(DirectorySizeService.computeSize(of: base), 150)
        let service = DirectorySizeService()
        let size = await service.size(for: base)
        XCTAssertEqual(size, 150)

        let archive = try FileActionService.compress(items: [sub], in: base)
        XCTAssertEqual(archive.pathExtension, "zip")
        XCTAssertTrue(FileManager.default.fileExists(atPath: archive.path))
    }

    func testDirectorySizeSkipsHiddenFiles() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        try String(repeating: "x", count: 100).write(to: base.appendingPathComponent("visible.txt"), atomically: true, encoding: .utf8)
        try String(repeating: "y", count: 900).write(to: base.appendingPathComponent(".hidden"), atomically: true, encoding: .utf8)
        XCTAssertEqual(DirectorySizeService.computeSize(of: base), 100)
    }

    func testProtectedFolderDetection() {
        let protected = [
            "/Users/aelmen/Desktop", "/Users/aelmen/Documents", "/Users/aelmen/Downloads",
            "/Users/aelmen/Pictures", "/Users/aelmen/Movies", "/Users/aelmen/Music",
            "/Users/aelmen/Library"
        ]
        for path in protected {
            XCTAssertTrue(DirectorySizeService.isProtectedFolder(URL(fileURLWithPath: path)), path)
        }
        let allowed = [
            "/Users/aelmen", "/Users/aelmen/Documents/Codex", "/Users/aelmen/Projects",
            "/Users", "/tmp/Desktop", "/Volumes/Data/Desktop"
        ]
        for path in allowed {
            XCTAssertFalse(DirectorySizeService.isProtectedFolder(URL(fileURLWithPath: path)), path)
        }
    }

    func testPermissionsRoundTrip() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let file = base.appendingPathComponent("note.txt")
        try "x".write(to: file, atomically: true, encoding: .utf8)

        try FilePermissionService.setPermissions(FilePermissions(octal: 0o600), for: file)
        let readBack = try FilePermissionService.permissions(for: file)
        XCTAssertEqual(readBack.octal, 0o600)
        XCTAssertEqual(readBack.octalString, "600")
        XCTAssertEqual(readBack.symbolic, "rw-------")
        XCTAssertEqual(FilePermissions(octal: 0o755).symbolic, "rwxr-xr-x")
    }

    func testOrganizePlanAndRun() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        for name in ["a.jpg", "b.pdf", "c.swift"] {
            try "x".write(to: base.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        let items = try FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)
        let plan = FileActionService.organizePlan(items: items)
        XCTAssertEqual(plan[.images]?.count, 1)
        XCTAssertEqual(plan[.documents]?.count, 1)
        XCTAssertEqual(plan[.code]?.count, 1)

        let moved = try FileActionService.organize(items: items, in: base)
        XCTAssertEqual(moved.values.reduce(0, +), 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Images/a.jpg").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Code/c.swift").path))
    }

    func testCreateFolderRenameUnpack() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let folder = try ArchiveService.createFolder(named: "New Folder", in: base)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertThrowsError(try ArchiveService.createFolder(named: "New Folder", in: base))
        XCTAssertThrowsError(try ArchiveService.createFolder(named: "  ", in: base))

        let renamed = try ArchiveService.rename(item: folder, to: "Renamed")
        XCTAssertEqual(renamed.lastPathComponent, "Renamed")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))

        // Pack then unpack round-trip.
        let file = renamed.appendingPathComponent("note.txt")
        try "pack me".write(to: file, atomically: true, encoding: .utf8)
        let archive = try FileActionService.compress(items: [renamed], in: base)
        let unpacked = try ArchiveService.unpack(archive: archive)
        let restored = unpacked.appendingPathComponent("Renamed/note.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: restored.path))
    }

    func testBatchCopyMoveStreamSkipsExisting() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = base.appendingPathComponent("src")
        let dest = base.appendingPathComponent("dst")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        try "new".write(to: source.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "old".write(to: dest.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "b".write(to: source.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)

        var finished: (done: Int, skipped: Int)?
        for try await event in TwinCore.fileCoordinator.batchCopyMove(
            urls: [source.appendingPathComponent("a.txt"), source.appendingPathComponent("b.txt")],
            to: dest, move: false
        ) {
            if case .finished(let done, let skipped) = event { finished = (done, skipped) }
        }
        XCTAssertEqual(finished?.done, 1)
        XCTAssertEqual(finished?.skipped, 1)
        // Existing file was NOT overwritten.
        XCTAssertEqual(try String(contentsOf: dest.appendingPathComponent("a.txt"), encoding: .utf8), "old")
    }

    func testTextFileServiceAndStreamedCopy() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let file = base.appendingPathComponent("note.txt")
        try TextFileService.saveText("hej Twin", at: file)
        XCTAssertEqual(try TextFileService.loadText(at: file), "hej Twin")

        let binary = base.appendingPathComponent("bin.dat")
        try Data([0xFF, 0xFE, 0x00, 0x01]).write(to: binary)
        XCTAssertThrowsError(try TextFileService.loadText(at: binary))

        // Streamed copy preserves bytes, including across the chunk boundary.
        let big = base.appendingPathComponent("big.txt")
        try String(repeating: "abcd", count: 300_000).write(to: big, atomically: true, encoding: .utf8)
        let copy = base.appendingPathComponent("big-copy.txt")
        try StreamedFileCopy.copy(from: big, to: copy)
        XCTAssertEqual(try Data(contentsOf: copy), try Data(contentsOf: big))
    }

    func testWorkspaceStoreAndBatchRename() throws {
        let suite = "TwinCoreTests.ws.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkspaceStore(defaults: defaults, key: "ws")
        XCTAssertTrue(store.load().isEmpty)
        let workspace = Workspace(name: "Dev", leftTabs: ["/tmp"], rightTabs: ["/tmp", "/"], activeSide: 1)
        store.save(workspace)
        XCTAssertEqual(store.load().first?.name, "Dev")
        XCTAssertEqual(store.load().first?.activeSide, 1)
        store.delete(id: workspace.id)
        XCTAssertTrue(store.load().isEmpty)

        // Batch rename preview is pure and deterministic.
        var rule = FileActionService.BatchRenameRule()
        rule.find = "img"
        rule.replace = "photo"
        rule.prefix = "2026-"
        let url = URL(fileURLWithPath: "/tmp/img_01.jpg")
        XCTAssertEqual(FileActionService.renamedName(for: url, rule: rule, index: 0), "2026-photo_01.jpg")
    }

    func testFolderSyncCompareAndRun() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = base.appendingPathComponent("src")
        let dest = base.appendingPathComponent("dst")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        try "same".write(to: source.appendingPathComponent("same.txt"), atomically: true, encoding: .utf8)
        try "same".write(to: dest.appendingPathComponent("same.txt"), atomically: true, encoding: .utf8)
        try "only-src".write(to: source.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)
        try "extra".write(to: dest.appendingPathComponent("extra.txt"), atomically: true, encoding: .utf8)
        try "longer-content".write(to: source.appendingPathComponent("diff.txt"), atomically: true, encoding: .utf8)
        try "x".write(to: dest.appendingPathComponent("diff.txt"), atomically: true, encoding: .utf8)

        let plan = FolderSyncService.compare(source: source, destination: dest)
        let states = Dictionary(uniqueKeysWithValues: plan.map { ($0.relativePath, $0.state) })
        XCTAssertEqual(states["same.txt"], .same)
        XCTAssertEqual(states["new.txt"], .onlyInSource)
        XCTAssertEqual(states["extra.txt"], .onlyInDestination)
        XCTAssertEqual(states["diff.txt"], .different)

        // Safe sync keeps extras.
        let result = try FolderSyncService.sync(source: source, destination: dest)
        XCTAssertEqual(result.copied, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.appendingPathComponent("extra.txt").path))
        XCTAssertEqual(try String(contentsOf: dest.appendingPathComponent("diff.txt"), encoding: .utf8), "longer-content")
        let remaining = FolderSyncService.compare(source: source, destination: dest)
            .filter { $0.state != .same && $0.state != .onlyInDestination }
        XCTAssertEqual(remaining.count, 0)
    }

    func testGitBadges() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        func git(_ args: [String]) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["-C", base.path] + args
            try? process.run()
            process.waitUntilExit()
        }
        git(["init", "-q"])
        git(["config", "user.email", "test@example.com"])
        git(["config", "user.name", "Test"])
        let tracked = base.appendingPathComponent("tracked.txt")
        try "v1".write(to: tracked, atomically: true, encoding: .utf8)
        git(["add", "."])
        git(["commit", "-qm", "init"])

        try "v2".write(to: tracked, atomically: true, encoding: .utf8)
        try "new".write(to: base.appendingPathComponent("untracked.txt"), atomically: true, encoding: .utf8)

        let badges = GitStatusService.badges(for: base)
        XCTAssertEqual(badges[tracked.path], .modified)
        XCTAssertEqual(badges[base.appendingPathComponent("untracked.txt").path], .untracked)
        XCTAssertNotNil(GitStatusService.repositoryRoot(for: base))
    }

    func testTwinHelpAnswers() {
        XCTAssertTrue(TwinHelp.answer(to: "How do I encrypt a file?").contains("Cmd+Shift+E"))
        XCTAssertTrue(TwinHelp.answer(to: "hur skyddar jag en mapp med behörigheter?").contains("Cmd+I"))
        XCTAssertTrue(TwinHelp.answer(to: "How do I copy to the other pane?").contains("Cmd+5"))
        XCTAssertTrue(TwinHelp.answer(to: "what do git badges mean?").lowercased().contains("git"))
        XCTAssertEqual(TwinHelp.answer(to: "unrelated question about weather"), TwinHelp.fallbackAnswer)
        XCTAssertFalse(TwinHelp.suggestions.isEmpty)
        XCTAssertTrue(TwinHelp.manual.contains("Backspace"))
    }

    func testInsightsCatalogAndPerformance() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        // Orphan: old loose file. Fresh file: not orphan. Risky: world-writable.
        let old = base.appendingPathComponent("old.txt")
        try "old".write(to: old, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -200 * 24 * 3600)], ofItemAtPath: old.path)
        let fresh = base.appendingPathComponent("fresh.txt")
        try "new".write(to: fresh, atomically: true, encoding: .utf8)
        try FilePermissionService.setPermissions(FilePermissions(octal: 0o666), for: fresh)
        try FileManager.default.createDirectory(at: base.appendingPathComponent("EmptyDir"), withIntermediateDirectories: false)

        let insights = FolderInsightsService.analyze(folder: base)
        XCTAssertTrue(insights.orphanFiles.map(\.lastPathComponent).contains("old.txt"))
        XCTAssertFalse(insights.orphanFiles.map(\.lastPathComponent).contains("fresh.txt"))
        XCTAssertEqual(insights.permissionRisks.map(\.url.lastPathComponent), ["fresh.txt"])
        XCTAssertTrue(insights.emptyFolders.map(\.lastPathComponent).contains("EmptyDir"))

        // Kartotek index lists files with MD5.
        let catalog = try FolderInsightsService.generateCatalog(for: base)
        let text = try String(contentsOf: catalog, encoding: .utf8)
        XCTAssertTrue(text.contains("fresh.txt"))
        XCTAssertTrue(text.contains("MD5"))

        // Performance guard: 300-file tree analyzed + sized well under generous bounds.
        let perf = base.appendingPathComponent("perf")
        try FileManager.default.createDirectory(at: perf, withIntermediateDirectories: true)
        for index in 0..<300 {
            try "x".write(to: perf.appendingPathComponent("f\(index).txt"), atomically: true, encoding: .utf8)
        }
        let start = Date()
        _ = FolderInsightsService.analyze(folder: perf)
        _ = DirectorySizeService.computeSize(of: perf)
        XCTAssertLessThan(Date().timeIntervalSince(start), 10)
    }

    // FileCoordinatorService: coordinated copy lands on disk.
    func testCoordinatedCopy() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let source = base.appendingPathComponent("a.txt")
        try "twin".write(to: source, atomically: true, encoding: .utf8)
        let destination = base.appendingPathComponent("b.txt")

        try FileCoordinatorService.shared.copyItem(at: source, to: destination)
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "twin")
    }
}
