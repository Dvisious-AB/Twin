import Foundation

/// Chunked copy that never loads a whole file into memory — safe for
/// multi-GB files. Shared by drag promises and any streamed copy need.
public enum StreamedFileCopy {
    public static let chunkSize = 1 << 20 // 1 MiB

    public static func copy(
        from source: URL,
        to destination: URL,
        onProgress: (@Sendable (UInt64) -> Void)? = nil,
        isCancelled: @Sendable () -> Bool = { false }
    ) throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        let values = try source.resourceValues(forKeys: [.isDirectoryKey])
        if values.isDirectory == true {
            try FileManager.default.copyItem(at: source, to: destination)
            return
        }
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let reader = try FileHandle(forReadingFrom: source)
        defer { try? reader.close() }
        let writer = try FileHandle(forWritingTo: destination)
        defer { try? writer.close() }
        var copied: UInt64 = 0
        while true {
            if isCancelled() {
                try? writer.close()
                try? FileManager.default.removeItem(at: destination)
                throw CancellationError()
            }
            let chunk = try reader.read(upToCount: chunkSize) ?? Data()
            if chunk.isEmpty { break }
            try writer.write(contentsOf: chunk)
            copied += UInt64(chunk.count)
            onProgress?(copied)
        }
    }
}

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
        case progress(fraction: Double, bytesDone: UInt64, bytesTotal: UInt64, currentItem: String)
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
                    // Byte totals up front so progress means something
                    // for a single multi-GB file, not just per item.
                    let itemBytes: [UInt64] = urls.map { url in
                        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                        if values?.isDirectory == true {
                            return DirectorySizeService.computeSize(of: url)
                        }
                        return UInt64(values?.fileSize ?? 0)
                    }
                    let bytesTotal = itemBytes.reduce(0, +)
                    var bytesDone: UInt64 = 0
                    var done = 0
                    var skipped = 0
                    var completedMoves: [JournalMove] = []
                    for (index, url) in urls.enumerated() {
                        try Task.checkCancellation()
                        let destination = directory.appendingPathComponent(url.lastPathComponent)
                        if FileManager.default.fileExists(atPath: destination.path) {
                            skipped += 1
                            bytesDone += itemBytes[index]
                        } else if move {
                            try self.moveItem(at: url, to: destination)
                            done += 1
                            completedMoves.append(JournalMove(from: url, to: destination))
                            bytesDone += itemBytes[index]
                        } else {
                            let base = bytesDone
                            try StreamedFileCopy.copy(from: url, to: destination, onProgress: { written in
                                continuation.yield(.progress(
                                    fraction: bytesTotal > 0 ? Double(base + written) / Double(bytesTotal) : 0,
                                    bytesDone: base + written,
                                    bytesTotal: bytesTotal,
                                    currentItem: url.lastPathComponent
                                ))
                            }, isCancelled: { Task.isCancelled })
                            done += 1
                            completedMoves.append(JournalMove(from: url, to: destination))
                            bytesDone += itemBytes[index]
                        }
                        continuation.yield(.progress(
                            fraction: bytesTotal > 0 ? Double(bytesDone) / Double(bytesTotal) : Double(index + 1) / Double(urls.count),
                            bytesDone: bytesDone,
                            bytesTotal: bytesTotal,
                            currentItem: url.lastPathComponent
                        ))
                    }
                    if done > 0 {
                        var record = OperationRecord(
                            kind: move ? .move : .copy,
                            title: "\(move ? "Moved" : "Copied") \(done) item(s) to \(directory.lastPathComponent)")
                        record.moves = completedMoves
                        OperationJournal.shared.record(record)
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
