import Foundation

/// Twin Lite — free App Store edition.
/// Included in Lite: dual-pane, drag-and-drop, tabs, Quick Look.
public enum TwinLite {
    public static let editionName = "Lite"
    public static let features: Set<LiteFeature> = [.dualPane, .dragDrop, .tabs, .quickLook]
}

public enum LiteFeature: String, Sendable, CaseIterable {
    case dualPane
    case dragDrop
    case tabs
    case quickLook
}
