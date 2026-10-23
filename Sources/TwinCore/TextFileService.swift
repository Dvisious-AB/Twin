import Foundation

/// Text file reading/writing for the editor — file I/O lives here,
/// the editor view only binds strings.
public enum TextFileService {
    public static let maxEditableBytes = 2_000_000

    public enum TextFileError: Error, LocalizedError, Sendable {
        case tooLarge(Int)
        case notText

        public var errorDescription: String? {
            switch self {
            case .tooLarge(let bytes): return "File is too large to edit (\(bytes) bytes)"
            case .notText: return "Not a UTF-8 text file"
            }
        }
    }

    public static func loadText(at url: URL) throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard size <= maxEditableBytes else { throw TextFileError.tooLarge(size) }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw TextFileError.notText
        }
        return text
    }

    public static func saveText(_ text: String, at url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
