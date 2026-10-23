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
