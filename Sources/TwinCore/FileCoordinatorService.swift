import Foundation

/// Coordinated file-system operations built on `NSFileCoordinator`.
///
/// Coordination matters on iCloud Drive and external volumes: another
/// process (Finder, iCloud daemon) may be writing the same item.
/// All operations coordinate reading/writing intents before touching disk.
public final class FileCoordinatorService: @unchecked Sendable {
    public static let shared = FileCoordinatorService()
    public init() {}

    public enum FileOperationError: Error, Sendable {
        case coordinationFailed(Error)
        case sourceMissing(URL)
    }

    // MARK: - Coordinated read

    /// Coordinated directory listing. Works for local, iCloud and external volumes.
    public func contentsOfDirectory(at url: URL) throws -> [URL] {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var result: [URL] = []
        var readError: Error?

        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { actualURL in
            do {
                result = try FileManager.default.contentsOfDirectory(
                    at: actualURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                )
            } catch {
                readError = error
            }
        }
        if let coordinationError { throw FileOperationError.coordinationFailed(coordinationError) }
        if let readError { throw readError }
        return result
    }

    // MARK: - Coordinated copy / move

    public func copyItem(at source: URL, to destination: URL) throws {
        try coordinateMoveOrCopy(source: source, destination: destination, move: false)
    }

    public func moveItem(at source: URL, to destination: URL) throws {
        try coordinateMoveOrCopy(source: source, destination: destination, move: true)
    }

    private func coordinateMoveOrCopy(source: URL, destination: URL, move: Bool) throws {
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw FileOperationError.sourceMissing(source)
        }
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var operationError: Error?

        coordinator.coordinate(
            writingItemAt: source, options: move ? .forMoving : [],
            writingItemAt: destination, options: .forReplacing,
            error: &coordinationError
        ) { actualSource, actualDestination in
            do {
                if FileManager.default.fileExists(atPath: actualDestination.path) {
                    try FileManager.default.removeItem(at: actualDestination)
                }
                if move {
                    try FileManager.default.moveItem(at: actualSource, to: actualDestination)
                } else {
                    try FileManager.default.copyItem(at: actualSource, to: actualDestination)
                }
            } catch {
                operationError = error
            }
        }
        if let coordinationError { throw FileOperationError.coordinationFailed(coordinationError) }
        if let operationError { throw operationError }
    }

    // MARK: - Batch with progress

    /// Events from a batch copy/move. UI consumes this instead of
    /// reimplementing the loop — one implementation, shared everywhere.
    public enum BatchEvent: Sendable {
        case progress(Double)
        case finished(done: Int, skipped: Int)
    }

    /// Copies (or moves) items into a directory as an async sequence of
    /// progress events. Existing targets are skipped (never silently
    /// overwritten) and counted in the final event.
    public func batchCopyMove(
        urls: [URL],
        to directory: URL,
        move: Bool
    ) -> AsyncThrowingStream<BatchEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard !urls.isEmpty else {
                        continuation.yield(.finished(done: 0, skipped: 0))
                        continuation.finish()
                        return
                    }
                    let total = Double(urls.count)
                    var done = 0
                    var skipped = 0
                    for (index, url) in urls.enumerated() {
                        try Task.checkCancellation()
                        let destination = directory.appendingPathComponent(url.lastPathComponent)
                        if FileManager.default.fileExists(atPath: destination.path) {
                            skipped += 1
                        } else if move {
                            try self.moveItem(at: url, to: destination)
                            done += 1
                        } else {
                            try self.copyItem(at: url, to: destination)
                            done += 1
                        }
                        continuation.yield(.progress(Double(index + 1) / total))
                    }
                    continuation.yield(.finished(done: done, skipped: skipped))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
