import Foundation

/// Persistent debug log: last-resort evidence when a user lands
/// somewhere the UI can't explain ("dead folder"). Ring buffer in
/// memory for the in-app viewer + JSON lines on disk so a log can
/// be sent to us and analysed after the fact.
///
/// File: Application Support/Twin/debug.log (rotated at ~512 KB).
public final class DebugLog: @unchecked Sendable {
    public static let shared = DebugLog()

    public struct Entry: Codable, Identifiable, Sendable {
        public var id: String { "\(timestamp.timeIntervalSince1970)-\(message.hashValue)" }
        public let timestamp: Date
        public let level: Level
        public let category: String
        public let message: String
        public let context: [String: String]

        public enum Level: String, Codable, Sendable {
            case info, warning, error
        }
    }

    private let directory: URL
    private let maxBytes: Int
    private let capacity = 300
    private let queue = DispatchQueue(label: "se.dvisious.twin.debuglog")
    private var buffer: [Entry] = []

    public var fileURL: URL { directory.appendingPathComponent("debug.log") }

    public init(directory: URL? = nil, maxBytes: Int = 512_000) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directory = base.appendingPathComponent("Twin", isDirectory: true)
        }
        self.maxBytes = maxBytes
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    public func log(_ level: Entry.Level, _ category: String, _ message: String,
                    context: [String: String] = [:]) {
        let entry = Entry(timestamp: Date(), level: level, category: category,
                          message: message, context: context)
        queue.async { [weak self] in
            guard let self else { return }
            buffer.append(entry)
            if buffer.count > capacity { buffer.removeFirst(buffer.count - capacity) }
            appendToFile(entry)
        }
    }

    public func info(_ category: String, _ message: String, context: [String: String] = [:]) {
        log(.info, category, message, context: context)
    }

    public func error(_ category: String, _ message: String, context: [String: String] = [:]) {
        log(.error, category, message, context: context)
    }

    /// Error with the fields that actually diagnose a dead folder:
    /// path, NSError domain/code and the classified load state.
    public func error(_ category: String, _ message: String, error: Error, path: String? = nil) {
        let ns = error as NSError
        var context = [
            "domain": ns.domain,
            "code": "\(ns.code)",
            "description": ns.localizedDescription
        ]
        if let path { context["path"] = path }
        log(.error, category, message, context: context)
    }

    public func entries() -> [Entry] {
        queue.sync { buffer }
    }

    /// Plain-text dump for pasteboard/sharing.
    public func textDump() -> String {
        let formatter = ISO8601DateFormatter()
        return entries().map { entry in
            let context = entry.context.sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            return "\(formatter.string(from: entry.timestamp)) [\(entry.level.rawValue)] "
                + "\(entry.category): \(entry.message) \(context)"
        }.joined(separator: "\n")
    }

    public func clear() {
        queue.async { [weak self] in
            self?.buffer.removeAll()
            if let self { try? FileManager.default.removeItem(at: fileURL) }
        }
    }

    /// Waits until pending writes landed (tests + copy actions).
    public func flush() {
        queue.sync {}
    }

    private func appendToFile(_ entry: Entry) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entry) else { return }
        var line = data
        line.append(0x0A)
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
            if let size = try? handle.offset(), size > UInt64(maxBytes) {
                rotate(keepingTailOf: handle)
            }
        } else {
            try? line.write(to: fileURL)
        }
    }

    /// Keeps the newest half of the file when it grows past the cap.
    private func rotate(keepingTailOf handle: FileHandle) {
        guard let data = try? Data(contentsOf: fileURL), data.count > maxBytes else { return }
        let tail = data.suffix(maxBytes / 2)
        // Start at a line boundary so the file stays valid JSON lines.
        let start = tail.firstIndex(of: 0x0A).map { tail.index(after: $0) } ?? tail.startIndex
        try? Data(tail[start...]).write(to: fileURL, options: .atomic)
    }
}
