import Cocoa
import FinderSync

final class FinderSyncExtension: FIFinderSync {
    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/Users")]
    }

    // MARK: - Toolbar item ("Twin View" in Finder toolbar)

    override var toolbarItemName: String {
        "Twin View"
    }

    override var toolbarItemToolTip: String {
        "Open this folder in Twin — Dual Pane"
    }

    override var toolbarItemImage: NSImage {
        NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Twin View")
            ?? NSImage(named: NSImage.folderName)!
    }

    // MARK: - Directory observation / badges

    override func beginObservingDirectory(at url: URL) {
        FIFinderSyncController.default().setBadgeIdentifier("Twin", for: url)
    }

    override func endObservingDirectory(at url: URL) {
        FIFinderSyncController.default().setBadgeIdentifier("", for: url)
    }

    override func requestBadgeIdentifier(for url: URL) {
        FIFinderSyncController.default().setBadgeIdentifier("Twin", for: url)
    }

    // MARK: - Context menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        let item = NSMenuItem(
            title: "Open in Twin",
            action: #selector(openInTwin(_:)),
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(item)
        return menu
    }

    @IBAction func openInTwin(_ sender: AnyObject?) {
        let controller = FIFinderSyncController.default()
        let urls = controller.selectedItemURLs() ?? controller.targetedURL().map { [$0] } ?? []
        for url in urls {
            let folder = isDirectory(url) ? url : url.deletingLastPathComponent()
            let encoded = folder.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let twinURL = URL(string: "twin://open?path=\(encoded)") {
                NSWorkspace.shared.open(twinURL)
            }
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
}
