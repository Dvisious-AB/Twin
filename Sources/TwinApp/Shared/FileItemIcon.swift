import AppKit
import SwiftUI
import TwinCore

/// Shared file/folder icon used by list, icon grid and dialogs.
/// Files use real Finder icons via NSWorkspace (correct per file
/// type). Folders Twin recognises by metadata — a git repo, a
/// Swift package, a samples library — get a semantic symbol in a
/// kind colour instead of the anonymous blue folder.
struct FileItemIcon: View {
    let item: FileItem
    var size: CGFloat = 16
    var folderKind: FolderKind = .generic

    var body: some View {
        if item.isDirectory, folderKind != .generic, let symbol = Self.symbol(for: folderKind) {
            semanticFolder(symbol: symbol, color: Self.color(for: folderKind))
        } else {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        }
    }

    /// Small sizes: just the symbol. Larger: folder with a badge.
    private func semanticFolder(symbol: String, color: Color) -> some View {
        Group {
            if size >= 24 {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "folder.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color(nsColor: .controlAccentColor).opacity(0.75))
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(.white, color)
                        .background(
                            Circle().fill(color)
                                .frame(width: size * 0.52, height: size * 0.52)
                        )
                        .frame(width: size * 0.52, height: size * 0.52)
                        .offset(x: size * 0.06, y: size * 0.06)
                }
            } else {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.92))
                    .foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
    }

    static func symbol(for kind: FolderKind) -> String? {
        switch kind {
        case .generic: return nil
        case .git: return "arrow.triangle.branch"
        case .swiftPackage: return "swift"
        case .xcodeProject: return "hammer.fill"
        case .node: return "curlybraces"
        case .rust: return "gearshape.fill"
        case .go: return "g.circle.fill"
        case .docker: return "shippingbox.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .samples: return "waveform"
        case .music: return "music.note"
        case .pictures: return "photo.fill"
        case .movies: return "film.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .documents: return "doc.text.fill"
        case .desktop: return "desktopcomputer"
        case .applications: return "square.grid.2x2.fill"
        }
    }

    static func color(for kind: FolderKind) -> Color {
        switch kind {
        case .generic: return .gray
        case .git: return .orange
        case .swiftPackage: return .orange
        case .xcodeProject: return .blue
        case .node: return .green
        case .rust: return .gray
        case .go: return .teal
        case .docker: return .blue
        case .code: return .teal
        case .samples: return .pink
        case .music: return .red
        case .pictures: return .green
        case .movies: return .gray
        case .downloads: return .blue
        case .documents: return .gray
        case .desktop: return .gray
        case .applications: return .blue
        }
    }
}
