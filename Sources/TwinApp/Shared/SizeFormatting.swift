import Foundation

/// One place for byte-count presentation across panes and dialogs.
enum SizeFormatting {
    static func string(forBytes bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    static func string(forBytes bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
