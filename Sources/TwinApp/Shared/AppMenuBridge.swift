import Foundation

/// Action/state bridge for the Total Commander-style menu bar.
/// DualPaneView owns the real state; it publishes closures and
/// enablement flags here so the App-level `.commands` (Files /
/// Commands / Show, TC-style) can reach the active pane.
@MainActor
final class AppMenuBridge: ObservableObject {
    static let shared = AppMenuBridge()

    @Published var hasSelection = false
    @Published var singleSelection = false
    @Published var archiveSelected = false
    @Published var canCloseTab = false
    @Published var proUnlocked = false

    var copy: () -> Void = {}
    var move: () -> Void = {}
    var edit: () -> Void = {}
    var pack: () -> Void = {}
    var unpack: () -> Void = {}
    var md5: () -> Void = {}
    var encrypt: () -> Void = {}
    var newFolder: () -> Void = {}
    var rename: () -> Void = {}
    var delete: () -> Void = {}
    var permissions: () -> Void = {}
    var assistant: () -> Void = {}
    var folderSync: () -> Void = {}
    var batchRename: () -> Void = {}
    var focusFilter: () -> Void = {}
    var setListView: () -> Void = {}
    var setIconView: () -> Void = {}
    var newTab: () -> Void = {}
    var closeTab: () -> Void = {}

    @Published var iCloudAvailable = false
    var goHome: () -> Void = {}
    var goDesktop: () -> Void = {}
    var goDocuments: () -> Void = {}
    var goDownloads: () -> Void = {}
    var goICloud: () -> Void = {}
}
