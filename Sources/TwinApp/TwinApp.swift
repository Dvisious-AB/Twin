import SwiftUI
import TwinCore

@main
struct TwinApp: App {
    init() {
        // FileSystemEngineer: resolve persisted security-scoped bookmarks at start.
        _ = TwinCore.restoreBookmarkedAccess()
    }

    var body: some Scene {
        WindowGroup {
            DualPaneView()
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}
