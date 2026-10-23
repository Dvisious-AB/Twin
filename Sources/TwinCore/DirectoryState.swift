import Foundation

/// User-presentable outcome of loading a folder in a pane.
/// Distinguishes "empty" from errors a user can act on.
public enum DirectoryLoadState: Equatable, Sendable {
    case loaded(itemCount: Int)
    case empty
    case permissionDenied(path: String)
    case notFound(path: String)
    case volumeUnavailable(path: String)
    case failed(message: String)

    public var isError: Bool {
        switch self {
        case .loaded, .empty: return false
        default: return true
        }
    }

    public var userMessage: String {
        switch self {
        case .loaded(let count): return "\(count) items"
        case .empty: return "Folder is empty"
        case .permissionDenied: return "No permission to read this folder. Grant access in System Settings or pick the folder again."
        case .notFound: return "Folder no longer exists."
        case .volumeUnavailable: return "Volume is not connected. Reconnect the disk and refresh."
        case .failed(let message): return message
        }
    }

    /// Classifies a directory-load error for display.
    public static func classify(error: Error, for url: URL) -> DirectoryLoadState {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileReadNoPermissionError, NSFileLockingError:
                return .permissionDenied(path: url.path)
            case NSFileReadNoSuchFileError, NSFileNoSuchFileError:
                return missingState(for: url)
            default:
                break
            }
        }
        if nsError.domain == NSPOSIXErrorDomain {
            switch nsError.code {
            case Int(EACCES), Int(EPERM):
                return .permissionDenied(path: url.path)
            case Int(ENOENT):
                return missingState(for: url)
            case Int(ENODEV), Int(ENXIO), Int(ESTALE):
                return .volumeUnavailable(path: url.path)
            default:
                break
            }
        }
        return .failed(message: nsError.localizedDescription)
    }

    /// A missing path on a mounted volume is "not found"; a missing volume root
    /// means the disk itself is gone.
    public static func missingState(for url: URL, fileManager: FileManager = .default) -> DirectoryLoadState {
        if let volumeURL = try? url.resourceValues(forKeys: [.volumeURLKey]).volume,
           !fileManager.fileExists(atPath: volumeURL.path) {
            return .volumeUnavailable(path: url.path)
        }
        // /Volumes/<name>/... where <name> itself is missing => disk disconnected.
        let components = url.pathComponents
        if components.count >= 3, components[1] == "Volumes" {
            let volumePath = "/Volumes/\(components[2])"
            if !fileManager.fileExists(atPath: volumePath) {
                return .volumeUnavailable(path: url.path)
            }
        }
        return .notFound(path: url.path)
    }

    public static func state(contents: [URL], for url: URL) -> DirectoryLoadState {
        contents.isEmpty ? .empty : .loaded(itemCount: contents.count)
    }
}
