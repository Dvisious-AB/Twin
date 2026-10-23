import Foundation

/// Twin Pro — paid unlock via StoreKit 2.
/// $24.99 / 249 kr one-time (launch 149 kr), lifetime + 1 year of updates,
/// then $12/year. Full purchase/verification flow: @StoreKitEngineer.
public enum TwinPro {
    public static let editionName = "Pro"
    public static let productID = "com.anderselmen.twin.pro"
    public static let features: Set<ProFeature> = [.workspaces, .folderSync, .batchRename, .gitBadges]
}

public enum ProFeature: String, Sendable, CaseIterable {
    case workspaces
    case folderSync
    case batchRename
    case gitBadges
}

/// Feature gate consulted by the UI. Defaults to locked until StoreKit
/// entitlement verification sets `isUnlocked`.
public final class ProFeatureGate: @unchecked Sendable {
    public static let shared = ProFeatureGate()
    private let lock = NSLock()
    private var unlocked = false

    public init() {}

    public var isUnlocked: Bool {
        lock.lock()
        defer { lock.unlock() }
        return unlocked
    }

    public func setUnlocked(_ value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        unlocked = value
    }

    public func canUse(_ feature: ProFeature) -> Bool {
        isUnlocked
    }
}
