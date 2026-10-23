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
