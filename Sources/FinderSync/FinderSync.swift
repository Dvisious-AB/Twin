import Cocoa
import FinderSync
class FinderSync: FIFinderSync {
  override init(){ super.init(); FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/Users")] }
  override func menu(for menuKind: FIMenuKind) -> NSMenu {
    let menu = NSMenu(title: "")
    let item = NSMenuItem(title: "Open in Twin - Dual Pane", action: #selector(openInTwin(_:)), keyEquivalent: "")
    menu.addItem(item)
    return menu
  }
  @IBAction func openInTwin(_ sender: AnyObject?){
    guard let urls = FIFinderSyncController.default().selectedItemURLs() else { return }
    for url in urls { let u = URL(string: "twin://open?path=\(url.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!; NSWorkspace.shared.open(u) }
  }
}
