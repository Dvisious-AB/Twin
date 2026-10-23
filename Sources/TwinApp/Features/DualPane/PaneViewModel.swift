import Foundation
import SwiftUI
struct FileItem: Identifiable, Hashable { var id: URL { url }; let url: URL; let name: String; let isDirectory: Bool; let size: UInt64 }
@MainActor class PaneViewModel: ObservableObject {
  @Published var currentURL: URL
  @Published var items: [FileItem]=[]
  @Published var selection = Set<URL>()
  init(initialPath: URL){ self.currentURL=initialPath; refresh() }
  func refresh(){
    let fm=FileManager.default
    guard let contents = try? fm.contentsOfDirectory(at: currentURL, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles]) else { return }
    items = contents.compactMap{ url in let v=try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]); return FileItem(url:url, name:url.lastPathComponent, isDirectory:v?.isDirectory ?? false, size:UInt64(v?.fileSize ?? 0)) }.sorted{ $0.name.lowercased() < $1.name.lowercased() }
  }
  func navigate(to url: URL){ currentURL=url; refresh() }
  func goUp(){ currentURL.deleteLastPathComponent(); refresh() }
  func copySelected(to dest: URL) async { for url in selection { try? FileManager.default.copyItem(at:url, to:dest.appendingPathComponent(url.lastPathComponent)) }; refresh() }
  func moveSelected(to dest: URL) async { for url in selection { try? FileManager.default.moveItem(at:url, to:dest.appendingPathComponent(url.lastPathComponent)) }; refresh() }
}
