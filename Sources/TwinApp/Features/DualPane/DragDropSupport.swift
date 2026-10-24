import AppKit
import TwinCore
import UniformTypeIdentifiers

// MARK: - NSFilePromise drag source

/// Delegate that fulfils an `NSFilePromiseProvider` by copying the source
/// file into the destination directory the system hands us. The copy runs
/// on the operation queue the system provides, keeping the UI responsive.
final class FilePromiseProviderDelegate: NSObject, NSFilePromiseProviderDelegate {
    let sourceURL: URL

    init(sourceURL: URL) {
        self.sourceURL = sourceURL
    }

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        fileNameForType fileType: String
    ) -> String {
        sourceURL.lastPathComponent
    }

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        do {
            try StreamedFileCopy.copy(from: sourceURL, to: url)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }
}

enum DragDropSupport {

    /// Retains promise delegates for the lifetime of a drag. AppKit does not
    /// retain the delegate, so we keep it alive until the drag session ends.
    private nonisolated(unsafe) static var retainedDelegates: [ObjectIdentifier: FilePromiseProviderDelegate] = [:]
    private static let retainedLock = NSLock()

    /// Builds an `NSItemProvider` that exposes `url` as an `NSFilePromise`.
    ///
    /// Consumers that understand file promises (Finder, other panes) receive
    /// a promise and only materialise the file on drop; plain file-URL
    /// consumers still get a usable URL representation.
    static func makeFilePromiseProvider(for url: URL) -> NSItemProvider {
        let delegate = FilePromiseProviderDelegate(sourceURL: url)
        let promiseProvider = NSFilePromiseProvider(
            fileType: UTType.item.identifier,
            delegate: delegate
        )
        promiseProvider.userInfo = ["url": url]

        retainedLock.lock()
        retainedDelegates[ObjectIdentifier(promiseProvider)] = delegate
        retainedLock.unlock()

        let itemProvider = NSItemProvider()
        itemProvider.suggestedName = url.lastPathComponent

        // File promise representation — fulfilled via FilePromiseProviderDelegate above.
        itemProvider.registerFileRepresentation(
            forTypeIdentifier: UTType.fileURL.identifier,
            fileOptions: [.openInPlace],
            visibility: .all
        ) { completion in
            // Materialise a copy in a temp dir for promise consumers.
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathComponent(url.lastPathComponent)
            do {
                try FileManager.default.createDirectory(
                    at: tempURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try StreamedFileCopy.copy(from: url, to: tempURL)
                completion(tempURL, true, nil)
            } catch {
                completion(nil, false, error)
            }
            return nil
        }

        // Plain URL representation for simple consumers.
        itemProvider.registerItem(forTypeIdentifier: UTType.fileURL.identifier, loadHandler: { completion, _, _ in
            completion?(url as NSURL, nil)
        })

        _ = promiseProvider // retained via delegate map above; provider itself is drag-session scoped
        return itemProvider
    }

    /// Loads file URLs from dropped providers.
    /// Supports both plain file URLs and file-promise representations.
    @MainActor
    static func loadFileURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers {
            if let url = await loadFileURL(from: provider) {
                urls.append(url)
            }
        }
        return urls
    }

    @MainActor
    private static func loadFileURL(from provider: NSItemProvider) async -> URL? {
        // Fast path: file URL item.
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            if let url = await loadItem(from: provider, typeIdentifier: UTType.fileURL.identifier) {
                return url
            }
        }
        // Promise path: load as data representation of a file.
        if provider.hasItemConformingToTypeIdentifier(UTType.item.identifier) {
            return await loadItem(from: provider, typeIdentifier: UTType.item.identifier)
        }
        return nil
    }

    @MainActor
    private static func loadItem(from provider: NSItemProvider, typeIdentifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                switch item {
                case let url as URL:
                    continuation.resume(returning: url)
                case let url as NSURL:
                    continuation.resume(returning: url as URL)
                case let data as Data:
                    // .draggable(URL) delivers the file URL as string
                    // data, not a URL object — accept both encodings.
                    let fromData = URL(dataRepresentation: data, relativeTo: nil)
                    let fromString = String(data: data, encoding: .utf8)
                        .flatMap { URL(string: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    continuation.resume(returning: fromData ?? fromString)
                default:
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
