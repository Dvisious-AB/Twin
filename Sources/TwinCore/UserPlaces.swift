import Foundation

/// The user's real places, resolved outside the app sandbox container.
/// `homeDirectoryForCurrentUser` points into the container when
/// sandboxed, so the real home is derived from the passwd entry
/// (with a container-path fallback).
public struct UserPlaces: Sendable {
    public let home: URL

    public init(home: URL) {
        self.home = home
    }

    public static var current: UserPlaces {
        if let passwdHome = FileManager.default.homeDirectory(forUser: NSUserName()),
           !passwdHome.path.contains("/Library/Containers/") {
            return UserPlaces(home: passwdHome)
        }
        // Fallback: strip /Library/Containers/<id>/Data from the
        // sandboxed home to recover /Users/<name>.
        let containerHome = FileManager.default.homeDirectoryForCurrentUser
        let components = containerHome.pathComponents
        if components.count >= 3, components[1] == "Users" {
            return UserPlaces(home: URL(fileURLWithPath: "/" + components[1...2].joined(separator: "/")))
        }
        return UserPlaces(home: containerHome)
    }

    public var desktop: URL { home.appendingPathComponent("Desktop") }
    public var documents: URL { home.appendingPathComponent("Documents") }
    public var downloads: URL { home.appendingPathComponent("Downloads") }

    /// iCloud Drive root, when iCloud Drive is set up on this Mac.
    public var iCloudDrive: URL? {
        let url = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Default right-pane start folder: Desktop when present,
    /// otherwise Documents.
    public var defaultRightPaneFolder: URL {
        exists(desktop) ? desktop : documents
    }
}
