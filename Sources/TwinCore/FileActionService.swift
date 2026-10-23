import CryptoKit
import Foundation

/// Keyboard-first file actions: compress, MD5, encrypt/decrypt, trash.
/// All operations are local and streaming where files can be large.
public enum FileActionService {

    public enum FileActionError: Error, LocalizedError, Sendable {
        case notAFile(URL)
        case wrongPassphrase
        case processFailed(String)

        public var errorDescription: String? {
            switch self {
            case .notAFile(let url): return "\(url.lastPathComponent) is not a regular file"
            case .wrongPassphrase: return "Wrong passphrase or damaged file"
            case .processFailed(let message): return message
            }
        }
    }

    // MARK: - Compress (Alt+F5 in Total Commander)

    /// Creates `<name>.zip` next to the first item (or `Archive.zip`),
    /// containing all given items. Uses ditto, no shell.
    @discardableResult
    public static func compress(items: [URL], in directory: URL) throws -> URL {
        guard !items.isEmpty else { throw FileActionError.processFailed("Nothing selected") }
        let base = items.count == 1 ? items[0].lastPathComponent : "Archive"
        var archive = directory.appendingPathComponent(base + ".zip")
        var counter = 1
        while FileManager.default.fileExists(atPath: archive.path) {
            counter += 1
            archive = directory.appendingPathComponent("\(base) \(counter).zip")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        var arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent"]
        // ditto takes one source per invocation for --keepParent; zip items one by one via a temp dir instead.
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        for item in items {
            try FileManager.default.copyItem(at: item, to: staging.appendingPathComponent(item.lastPathComponent))
        }
        arguments = ["-c", "-k", "--sequesterRsrc", staging.path, archive.path]
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw FileActionError.processFailed("Compression failed (ditto exit \(process.terminationStatus))")
        }
        return archive
    }

    // MARK: - MD5 checksum file

    /// Streams the file through MD5 and writes `<file>.md5` next to it.
    @discardableResult
    public static func createMD5File(for url: URL) throws -> URL {
        let hex = try md5Hex(of: url)
        let checksumURL = url.appendingPathExtension("md5")
        try "\(hex)  \(url.lastPathComponent)\n".write(to: checksumURL, atomically: true, encoding: .utf8)
        return checksumURL
    }

    public static func md5Hex(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = Insecure.MD5()
        while true {
            let chunk = try handle.read(upToCount: 1 << 20) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Organize (assistant: sort files into category folders)

    public enum FileCategory: String, CaseIterable, Sendable {
        case images = "Images"
        case documents = "Documents"
        case archives = "Archives"
        case audio = "Audio"
        case video = "Video"
        case code = "Code"
        case other = "Other"

        public static func category(for url: URL) -> FileCategory {
            switch url.pathExtension.lowercased() {
            case "jpg", "jpeg", "png", "gif", "heic", "tiff", "svg", "webp": return .images
            case "pdf", "doc", "docx", "txt", "md", "rtf", "pages", "odt": return .documents
            case "zip", "tar", "gz", "xz", "7z", "rar", "dmg": return .archives
            case "mp3", "wav", "flac", "aac", "ogg": return .audio
            case "mp4", "mov", "mkv", "avi", "webm": return .video
            case "swift", "py", "js", "ts", "go", "rs", "c", "h", "cpp", "java", "json", "yml", "yaml": return .code
            default: return .other
            }
        }
    }

    /// Preview of an organize run: category -> files that would move there.
    public static func organizePlan(items: [URL]) -> [FileCategory: [URL]] {
        var plan: [FileCategory: [URL]] = [:]
        for url in items {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard !isDirectory else { continue }
            plan[FileCategory.category(for: url), default: []].append(url)
        }
        return plan
    }

    /// Moves files into category subfolders of `directory`. Returns moved count per category.
    @discardableResult
    public static func organize(items: [URL], in directory: URL) throws -> [FileCategory: Int] {
        let plan = organizePlan(items: items)
        var moved: [FileCategory: Int] = [:]
        for (category, files) in plan {
            let folder = directory.appendingPathComponent(category.rawValue)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for file in files {
                let target = folder.appendingPathComponent(file.lastPathComponent)
                if FileManager.default.fileExists(atPath: target.path) { continue }
                try TwinCore.fileCoordinator.moveItem(at: file, to: target)
                moved[category, default: 0] += 1
            }
        }
        return moved
    }

    // MARK: - Trash (F8 in Total Commander — never hard delete)

    public static func trash(items: [URL]) throws {
        for item in items {
            try FileManager.default.trashItem(at: item, resultingItemURL: nil)
        }
    }

    // MARK: - Encrypt / decrypt (AES-GCM, key from passphrase)

    public static let encryptedExtension = "twinenc"

    private static func key(from passphrase: String) -> SymmetricKey {
        SymmetricKey(data: SHA256.hash(data: Data(passphrase.utf8)))
    }

    @discardableResult
    public static func encrypt(file: URL, passphrase: String) throws -> URL {
        let data = try Data(contentsOf: file)
        let sealed = try AES.GCM.seal(data, using: key(from: passphrase))
        guard let combined = sealed.combined else { throw FileActionError.wrongPassphrase }
        let output = file.appendingPathExtension(encryptedExtension)
        try combined.write(to: output)
        return output
    }

    @discardableResult
    public static func decrypt(file: URL, passphrase: String) throws -> URL {
        let data = try Data(contentsOf: file)
        do {
            let box = try AES.GCM.SealedBox(combined: data)
            let plain = try AES.GCM.open(box, using: key(from: passphrase))
            var output = file
            output.deletePathExtension()
            if FileManager.default.fileExists(atPath: output.path) {
                output = file.deletingPathExtension().appendingPathExtension("decrypted")
                    .appendingPathExtension(file.deletingPathExtension().pathExtension)
            }
            try plain.write(to: output)
            return output
        } catch {
            throw FileActionError.wrongPassphrase
        }
    }
}
