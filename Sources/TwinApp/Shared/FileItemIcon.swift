import AppKit
import SwiftUI

/// Shared file/folder icon used by list, icon grid and dialogs.
/// Real Finder icons via NSWorkspace (correct per file type, packages
/// and folders) instead of generic SF Symbols (UX review P1-8).
struct FileItemIcon: View {
    let item: FileItem
    var size: CGFloat = 16

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}
