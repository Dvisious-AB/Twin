import Foundation
import StoreKit

/// StoreKit 2 manager for Twin Pro.
/// Product: `com.dvisious.twin.pro` (non-consumable, $24.99 / 249 kr,
/// launch 149 kr). Test locally with `Configuration.storekit`.
@MainActor
public final class StoreKitManager: ObservableObject {
    public static let shared = StoreKitManager()

    @Published public private(set) var product: Product?
    @Published public private(set) var isProUnlocked = false
    @Published public private(set) var purchaseInFlight = false

    private var updatesTask: Task<Void, Never>?

    public init() {
        updatesTask = listenForTransactions()
        Task { await refresh() }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Load + entitlement check

    public func refresh() async {
        product = try? await Product.products(for: [TwinPro.productID]).first
        await updateEntitlement()
    }

    /// Entitlement check: any verified, non-revoked transaction for Pro unlocks.
    public func updateEntitlement() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == TwinPro.productID, transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isProUnlocked = unlocked
        ProFeatureGate.shared.setUnlocked(unlocked)
    }

    // MARK: - Purchase

    public enum PurchaseOutcome: Sendable {
        case success
        case userCancelled
        case pending
        case failed(String)
    }

    public func purchase() async -> PurchaseOutcome {
        guard let product else { return .failed("Product not loaded") }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return .failed("Unverified transaction")
                }
                await transaction.finish()
                await updateEntitlement()
                return .success
            case .userCancelled:
                return .userCancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("Unknown purchase result")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Restore purchases

    /// Restore via App Store sync, then re-check entitlements.
    public func restorePurchases() async throws {
        try await AppStore.sync()
        await updateEntitlement()
    }

    // MARK: - Transaction listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.updateEntitlement()
            }
        }
    }
}
