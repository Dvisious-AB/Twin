import SwiftUI
import TwinCore

@main
struct TwinApp: App {
    @ObservedObject private var menuBridge = AppMenuBridge.shared

    init() {
        // FileSystemEngineer: resolve persisted security-scoped bookmarks at start.
        _ = TwinCore.restoreBookmarkedAccess()
    }

    var body: some Scene {
        WindowGroup {
            DualPaneView()
                .frame(minWidth: 900, minHeight: 600)
        }
        // Total Commander-style menu bar: Files / Commands / Show.
        // Actions route through AppMenuBridge to the active pane.
        .commands {
            CommandMenu("Files") {
                Button("Pack (Zip)") { menuBridge.pack() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .disabled(!menuBridge.hasSelection)
                Button("Unpack") { menuBridge.unpack() }
                    .keyboardShortcut("u", modifiers: [.command, .shift])
                    .disabled(!menuBridge.archiveSelected)
                Button("Create MD5…") { menuBridge.md5() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                    .disabled(!menuBridge.hasSelection)
                Button("Encrypt / Decrypt…") { menuBridge.encrypt() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(!menuBridge.hasSelection)
                Divider()
                Button("View (F3)") { menuBridge.view() }
                    .disabled(!menuBridge.hasSelection)
                Button("File Type Handlers…") { menuBridge.handlersGuide() }
                Button("Edit") { menuBridge.edit() }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(!menuBridge.hasSelection)
                Button("New Folder") { menuBridge.newFolder() }
                    .keyboardShortcut("7", modifiers: .command)
                Button("Rename…") { menuBridge.rename() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .disabled(!menuBridge.singleSelection)
                Divider()
                Button("Move to Trash") { menuBridge.delete() }
                    .keyboardShortcut(.delete, modifiers: .command)
                    .disabled(!menuBridge.hasSelection)
            }
            CommandMenu("Commands") {
                Button("Copy to Other Pane (F5)") { menuBridge.copy() }
                    .keyboardShortcut("5", modifiers: .command)
                    .disabled(!menuBridge.hasSelection)
                Button("Move to Other Pane (F6)") { menuBridge.move() }
                    .keyboardShortcut("6", modifiers: .command)
                    .disabled(!menuBridge.hasSelection)
                Divider()
                Button("Folder Sync…") { menuBridge.folderSync() }
                Button("Batch Rename…") { menuBridge.batchRename() }
                    .disabled(!menuBridge.hasSelection)
                Divider()
                Button("Find Files…") { menuBridge.findFiles() }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                Button("Assistant…") { menuBridge.assistant() }
                Button("Permissions…") { menuBridge.permissions() }
                    .keyboardShortcut("i", modifiers: .command)
                    .disabled(!menuBridge.singleSelection)
            }
            CommandMenu("Go") {
                Button("Home") { menuBridge.goHome() }
                Button("Desktop") { menuBridge.goDesktop() }
                Button("Documents") { menuBridge.goDocuments() }
                Button("Downloads") { menuBridge.goDownloads() }
                Divider()
                Button("iCloud Drive") { menuBridge.goICloud() }
                    .disabled(!menuBridge.iCloudAvailable)
            }
            CommandMenu("Show") {
                Button("List View") { menuBridge.setListView() }
                    .keyboardShortcut("3", modifiers: .command)
                Button("Icon View") { menuBridge.setIconView() }
                    .keyboardShortcut("4", modifiers: .command)
                Divider()
                Button("Filter") { menuBridge.focusFilter() }
                    .keyboardShortcut("f", modifiers: .command)
                Divider()
                Button("New Tab") { menuBridge.newTab() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("Close Tab") { menuBridge.closeTab() }
                    .keyboardShortcut("w", modifiers: .command)
                    .disabled(!menuBridge.canCloseTab)
            }
        }
    }
}
