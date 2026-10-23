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

    /// Copies (or moves) items into a directory, reporting 0...1 progress per item.
    /// Progress handler is called on the caller's context; hop to MainActor in UI code.
    public func performBatch(
        urls: [URL],
        to directory: URL,
        move: Bool,
        progress: @Sendable (Double) -> Void
    ) async throws {
        guard !urls.isEmpty else { progress(1); return }
        let total = Double(urls.count)
        for (index, url) in urls.enumerated() {
            try Task.checkCancellation()
            let destination = directory.appendingPathComponent(url.lastPathComponent)
            if move {
                try moveItem(at: url, to: destination)
            } else {
                try copyItem(at: url, to: destination)
            }
            progress(Double(index + 1) / total)
        }
    }
}
