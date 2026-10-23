import SwiftUI

/// Shared file/folder icon used by list, icon grid and dialogs.
struct FileItemIcon: View {
    let item: FileItem
    var size: CGFloat = 14

    var body: some View {
        Image(systemName: item.isDirectory ? "folder.fill" : "doc")
            .font(.system(size: size))
            .foregroundStyle(item.isDirectory ? Color.blue : Color.secondary)
    }
}
