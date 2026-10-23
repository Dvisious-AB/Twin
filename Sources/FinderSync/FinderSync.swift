import Cocoa
import FinderSync

final class FinderSyncExtension: FIFinderSync {
    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/Users")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        let item = NSMenuItem(
            title: "Open in Twin - Dual Pane",
            action: #selector(openInTwin(_:)),
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(item)
        return menu
    }

    @IBAction func openInTwin(_ sender: AnyObject?) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs() else { return }
        for url in urls {
            let encoded = url.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let twinURL = URL(string: "twin://open?path=\(encoded)") {
                NSWorkspace.shared.open(twinURL)
            }
        }
    }
}
