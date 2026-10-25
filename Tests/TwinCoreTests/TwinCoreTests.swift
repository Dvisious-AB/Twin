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

    func testBatchCopyReportsByteProgress() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = base.appendingPathComponent("src")
        let dest = base.appendingPathComponent("dst")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let file = source.appendingPathComponent("big.bin")
        try Data(count: 3 * 1024 * 1024).write(to: file)

        var lastFraction = -1.0
        var finished: (Int, Int)?
        for try await event in TwinCore.fileCoordinator.batchCopyMove(urls: [file], to: dest, move: false) {
            switch event {
            case .progress(let fraction, let bytesDone, let bytesTotal, let name):
                XCTAssertEqual(name, "big.bin")
                XCTAssertEqual(bytesTotal, 3 * 1024 * 1024)
                XCTAssertLessThanOrEqual(bytesDone, bytesTotal)
                lastFraction = fraction
            case .finished(let done, let skipped):
                finished = (done, skipped)
            }
        }
        XCTAssertEqual(lastFraction, 1.0)
        XCTAssertEqual(finished?.0, 1)
        XCTAssertEqual(finished?.1, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.appendingPathComponent("big.bin").path))
    }

    func testStreamedCopyCancellationRemovesPartialFile() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let source = base.appendingPathComponent("src.bin")
        try Data(count: 5 * 1024 * 1024).write(to: source)
        let dest = base.appendingPathComponent("dst.bin")
        XCTAssertThrowsError(
            try StreamedFileCopy.copy(from: source, to: dest, isCancelled: { true })
        ) { error in
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: dest.path))
    }

    func testDirectorySizeSkipsHiddenFiles() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        try String(repeating: "x", count: 100).write(to: base.appendingPathComponent("visible.txt"), atomically: true, encoding: .utf8)
        try String(repeating: "y", count: 900).write(to: base.appendingPathComponent(".hidden"), atomically: true, encoding: .utf8)
        XCTAssertEqual(DirectorySizeService.computeSize(of: base), 100)
    }

    func testUserPlaces() {
        let places = UserPlaces(home: URL(fileURLWithPath: "/Users/tester"))
        XCTAssertEqual(places.desktop.path, "/Users/tester/Desktop")
        XCTAssertEqual(places.documents.path, "/Users/tester/Documents")
        XCTAssertEqual(places.downloads.path, "/Users/tester/Downloads")
        // No iCloud Drive under a nonexistent home.
        XCTAssertNil(places.iCloudDrive)
        // Desktop missing → Documents is the right-pane default.
        XCTAssertEqual(places.defaultRightPaneFolder.path, "/Users/tester/Documents")
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
        let setup = TwinHelp.answer(to: "How do I set up Apple Intelligence?")
        XCTAssertTrue(setup.contains("Language & Region"))
        XCTAssertTrue(setup.contains("must match"))
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

final class FileTypeRegistryTests: XCTestCase {
    func testClassification() {
        XCTAssertEqual(FileTypeRegistry.kind(forExtension: "md"), .markdown)
        XCTAssertEqual(FileTypeRegistry.kind(forExtension: ".SWIFT"), .code)
        XCTAssertEqual(FileTypeRegistry.kind(forExtension: "json"), .code)
        XCTAssertEqual(FileTypeRegistry.kind(forExtension: "png"), .image)
        XCTAssertEqual(FileTypeRegistry.kind(forExtension: "pdf"), .pdf)
        XCTAssertEqual(FileTypeRegistry.kind(forExtension: "mp4"), .video)
        XCTAssertEqual(FileTypeRegistry.kind(forExtension: "zip"), .archive)
        XCTAssertEqual(FileTypeRegistry.kind(forExtension: "txt"), .text)
        XCTAssertEqual(FileTypeRegistry.kind(forExtension: "zzzunknown"), .data)
        XCTAssertEqual(FileTypeRegistry.kind(for: URL(fileURLWithPath: "/a/b/photo.HEIC")), .image)
    }

    func testDefaultsWithoutAssociation() throws {
        let suite = "TwinCoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = FileHandlerStore(defaults: defaults)
        let md = URL(fileURLWithPath: "/tmp/notes.md")
        XCTAssertEqual(store.viewer(for: md), .twinViewer(.markdown))
        XCTAssertEqual(store.editor(for: md), .twinEditor)
        // No editor override set: Open still means macOS default.
        XCTAssertEqual(store.open(for: md), .systemDefault)
        let png = URL(fileURLWithPath: "/tmp/pic.png")
        XCTAssertEqual(store.viewer(for: png), .twinViewer(.image))
        XCTAssertEqual(store.editor(for: png), .systemDefault)
    }

    func testAssociationOverridesSystemDefault() throws {
        let suite = "TwinCoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = FileHandlerStore(defaults: defaults)
        store.setAssociation(
            FileTypeAssociation(editor: .externalApp(path: "/Applications/Zed.app", name: "Zed")),
            forExtension: "swift")
        let file = URL(fileURLWithPath: "/tmp/main.swift")
        XCTAssertEqual(store.editor(for: file), .externalApp(path: "/Applications/Zed.app", name: "Zed"))
        XCTAssertEqual(store.open(for: file), .externalApp(path: "/Applications/Zed.app", name: "Zed"))
        // A fresh store over the same defaults sees the persisted choice.
        let reloaded = FileHandlerStore(defaults: defaults)
        XCTAssertEqual(reloaded.editor(for: file), .externalApp(path: "/Applications/Zed.app", name: "Zed"))
    }

    func testCustomHandlerLifecycle() throws {
        let suite = "TwinCoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = FileHandlerStore(defaults: defaults)
        let handler = CustomHandler(
            name: "My Hex Editor", extensions: ["bin", ".dat"],
            commandTemplate: "/usr/bin/xxd {file} > /tmp/dump.txt")
        store.upsertCustomHandler(handler)
        let bin = URL(fileURLWithPath: "/tmp/firmware.bin")
        XCTAssertEqual(store.editor(for: bin), .custom(handler))
        store.removeCustomHandler(id: handler.id)
        XCTAssertEqual(store.editor(for: bin), .systemDefault)
        XCTAssertTrue(store.customHandlers.isEmpty)
    }
}

final class FileSearchServiceTests: XCTestCase {
    private func makeTree() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("TwinSearch-\(UUID().uuidString)")
        let sub = root.appendingPathComponent("sub/deep")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try "hello world".write(to: root.appendingPathComponent("notes.txt"),
                                atomically: true, encoding: .utf8)
        try "nothing here".write(to: sub.appendingPathComponent("other.md"),
                                 atomically: true, encoding: .utf8)
        try "say hello again".write(to: sub.appendingPathComponent("deep.log"),
                                    atomically: true, encoding: .utf8)
        try "hidden hello".write(to: root.appendingPathComponent(".secret.txt"),
                                 atomically: true, encoding: .utf8)
        return root
    }

    func testNameSearchIsRecursive() async throws {
        let root = try makeTree()
        defer { try? FileManager.default.removeItem(at: root) }
        var query = FileSearchService.Query()
        query.nameText = "deep"
        let outcome = FileSearchService.search(in: root, query: query)
        // Both the folder named "deep" and deep.log inside it match.
        XCTAssertEqual(Set(outcome.matches.map(\.url.lastPathComponent)), ["deep", "deep.log"])
        XCTAssertFalse(outcome.truncated)
    }

    func testContentSearchFindsSnippetAndSkipsHidden() async throws {
        let root = try makeTree()
        defer { try? FileManager.default.removeItem(at: root) }
        var query = FileSearchService.Query()
        query.contentText = "hello"
        let outcome = FileSearchService.search(in: root, query: query)
        let names = Set(outcome.matches.map(\.url.lastPathComponent))
        XCTAssertEqual(names, ["notes.txt", "deep.log"])
        let notes = try XCTUnwrap(outcome.matches.first { $0.url.lastPathComponent == "notes.txt" })
        XCTAssertEqual(notes.snippet, "hello world")

        query.includeHidden = true
        let withHidden = FileSearchService.search(in: root, query: query)
        XCTAssertTrue(Set(withHidden.matches.map(\.url.lastPathComponent)).contains(".secret.txt"))
    }

    func testResultCapTruncates() async throws {
        let root = try makeTree()
        defer { try? FileManager.default.removeItem(at: root) }
        var query = FileSearchService.Query()
        query.contentText = "hello"
        query.maxResults = 1
        let outcome = FileSearchService.search(in: root, query: query)
        XCTAssertEqual(outcome.matches.count, 1)
        XCTAssertTrue(outcome.truncated)
    }
}

final class DebugLogTests: XCTestCase {
    func testLogWritesFileAndDump() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TwinLog-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let log = DebugLog(directory: dir)
        log.info("navigation", "opened folder", context: ["path": "/tmp/x"])
        log.error("pane.load", "load failed",
                  error: NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError),
                  path: "/private/secret")
        log.flush()

        let entries = log.entries()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[1].context["code"], "\(NSFileReadNoPermissionError)")
        XCTAssertEqual(entries[1].context["path"], "/private/secret")
        let dump = log.textDump()
        XCTAssertTrue(dump.contains("pane.load"))
        let fileText = try String(contentsOf: log.fileURL, encoding: .utf8)
        XCTAssertEqual(fileText.split(separator: "\n").count, 2)

        log.clear()
        log.flush()
        XCTAssertTrue(log.entries().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: log.fileURL.path))
    }

    func testRotationKeepsTail() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TwinLog-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let log = DebugLog(directory: dir, maxBytes: 600)
        for index in 0..<40 {
            log.info("bulk", "entry number \(index) with some padding text to fill the file")
        }
        log.flush()
        let size = try FileManager.default.attributesOfItem(atPath: log.fileURL.path)[.size] as? Int ?? 0
        XCTAssertLessThanOrEqual(size, 700)
        let text = try String(contentsOf: log.fileURL, encoding: .utf8)
        XCTAssertTrue(text.contains("entry number 39"))
    }
}

final class FolderFactsTests: XCTestCase {
    private func facts() -> FolderFacts {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        return FolderFacts(files: [
            FolderFacts.FileFact(name: "small.txt", isDirectory: false, sizeBytes: 10,
                                 modified: now, accessed: now, owner: "anders"),
            FolderFacts.FileFact(name: "movie.mp4", isDirectory: false, sizeBytes: 900_000,
                                 modified: now.addingTimeInterval(-1000),
                                 accessed: now.addingTimeInterval(5000), owner: "anders"),
            FolderFacts.FileFact(name: "notes.md", isDirectory: false, sizeBytes: 100,
                                 modified: now.addingTimeInterval(9000),
                                 accessed: now.addingTimeInterval(-5000), owner: "maria")
        ])
    }

    func testLargestAnswer() {
        let answer = facts().answer(to: "vilken fil tar störst plats?")
        XCTAssertTrue(answer?.contains("movie.mp4") == true)
        XCTAssertTrue(facts().answer(to: "which file is the largest?")?.contains("movie.mp4") == true)
    }

    func testLastUsedAndOwnerAnswers() {
        XCTAssertTrue(facts().answer(to: "när användes en fil senast?")?.contains("movie.mp4") == true)
        let owners = facts().answer(to: "vem skapade filerna?")
        XCTAssertTrue(owners?.contains("anders") == true)
        XCTAssertTrue(owners?.contains("maria") == true)
    }

    func testNonFactQuestionReturnsNil() {
        XCTAssertNil(facts().answer(to: "How do I encrypt a file?"))
        XCTAssertTrue(facts().contextSummary(folderName: "Docs").contains("Largest: movie.mp4"))
    }
}

final class TwinLanguageTests: XCTestCase {
    func testLanguageDetection() {
        XCTAssertEqual(TwinLanguage.code(from: "sv-SE"), "sv")
        XCTAssertEqual(TwinLanguage.code(from: "en-US"), "en")
        XCTAssertEqual(TwinLanguage.code(from: nil), "en")
        XCTAssertEqual(TwinLanguage.code(from: ""), "en")
    }

    func testSwedishHelpAnswers() {
        let sv = TwinHelp.answer(to: "hur krypterar jag en fil?", languageCode: "sv")
        XCTAssertTrue(sv.contains("lösenfras"))
        let en = TwinHelp.answer(to: "how do I encrypt a file?", languageCode: "en")
        XCTAssertTrue(en.contains("passphrase"))
        XCTAssertTrue(TwinHelp.answer(to: "zz okänt ämne", languageCode: "sv").contains("Jag svarar"))
        XCTAssertTrue(TwinHelp.answer(to: "zz unknown topic", languageCode: "de").contains("I answer"))
    }
}
