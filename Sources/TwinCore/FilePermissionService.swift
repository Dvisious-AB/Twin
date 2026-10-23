import Foundation

/// POSIX permissions made simple: read/write/execute for owner, group, others.
/// This is the beginner-friendly face of chmod — no octal required in the UI,
/// but the octal value is always available for advanced users.
public struct FilePermissions: Equatable, Hashable, Sendable {
    public var owner: Int  // 0...7 bitmask r=4 w=2 x=1
    public var group: Int
    public var others: Int

    public init(owner: Int, group: Int, others: Int) {
        self.owner = owner & 0o7
        self.group = group & 0o7
        self.others = others & 0o7
    }

    public init(octal: Int) {
        self.init(owner: (octal >> 6) & 0o7, group: (octal >> 3) & 0o7, others: octal & 0o7)
    }

    public var octal: Int { (owner << 6) | (group << 3) | others }
    public var octalString: String { String(format: "%03o", octal) }

    public var symbolic: String {
        func triad(_ bits: Int) -> String {
            (bits & 4 != 0 ? "r" : "-") + (bits & 2 != 0 ? "w" : "-") + (bits & 1 != 0 ? "x" : "-")
        }
        return triad(owner) + triad(group) + triad(others)
    }
}

public enum FilePermissionService {
    public static func permissions(for url: URL) throws -> FilePermissions {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let raw = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0o644
        return FilePermissions(octal: raw)
    }

    public static func setPermissions(_ permissions: FilePermissions, for url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: permissions.octal)],
            ofItemAtPath: url.path
        )
    }

    /// Sensible presets for beginners.
    public static let presets: [(name: String, value: FilePermissions)] = [
        ("Private (only me)", FilePermissions(octal: 0o700)),
        ("Read & write for me, read for others", FilePermissions(octal: 0o644)),
        ("Shared in group", FilePermissions(octal: 0o770)),
        ("Read-only", FilePermissions(octal: 0o444)),
        ("Everyone can read & write", FilePermissions(octal: 0o666))
    ]
}
