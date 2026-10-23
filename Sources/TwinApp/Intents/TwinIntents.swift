import AppIntents
import Foundation
import TwinCore

/// Siri / Shortcuts / Spotlight actions for Twin.
/// "Organize folder with Twin", "Create MD5 with Twin" — they run Twin's
/// own TwinCore services on the path given, no UI required.

struct OrganizeFolderIntent: AppIntent {
    static let title: LocalizedStringResource = "Organize Folder with Twin"
    static let description = IntentDescription("Sorts loose files into category subfolders.")

    @Parameter(title: "Folder path", description: "Full path of the folder to organize")
    var folderPath: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let folder = URL(fileURLWithPath: (folderPath as NSString).expandingTildeInPath)
        let items = try FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )
        let moved = try FileActionService.organize(items: items, in: folder)
        let total = moved.values.reduce(0, +)
        return .result(dialog: "Sorted \(total) file(s) into \(moved.count) folder(s) in \(folder.lastPathComponent).")
    }
}

struct CreateMD5Intent: AppIntent {
    static let title: LocalizedStringResource = "Create MD5 Checksum with Twin"
    static let description = IntentDescription("Creates a .md5 checksum file next to the given file.")

    @Parameter(title: "File path", description: "Full path of the file to checksum")
    var filePath: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let file = URL(fileURLWithPath: (filePath as NSString).expandingTildeInPath)
        let checksum = try FileActionService.createMD5File(for: file)
        return .result(dialog: "Created \(checksum.lastPathComponent).")
    }
}

struct TwinShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OrganizeFolderIntent(),
            phrases: [
                "Organize folder with \(.applicationName)",
                "Sort folder with \(.applicationName)"
            ],
            shortTitle: "Organize Folder",
            systemImageName: "folder.badge.gearshape"
        )
        AppShortcut(
            intent: CreateMD5Intent(),
            phrases: [
                "Create MD5 with \(.applicationName)",
                "Checksum file with \(.applicationName)"
            ],
            shortTitle: "Create MD5",
            systemImageName: "number.hash"
        )
    }
}
