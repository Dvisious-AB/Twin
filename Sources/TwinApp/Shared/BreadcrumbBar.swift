import SwiftUI

/// Shared breadcrumb path bar used by every pane.
/// One component, one behaviour — no per-pane copies.
struct BreadcrumbBar: View {
    let crumbs: [Breadcrumb]
    var onNavigate: (Breadcrumb) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(Array(crumbs.enumerated()), id: \.element.id) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Button(crumb.name) { onNavigate(crumb) }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .lineLimit(1)
                        .help(crumb.url.path)
                }
            }
        }
    }
}
