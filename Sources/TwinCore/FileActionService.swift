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
