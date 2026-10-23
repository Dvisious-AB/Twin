import SwiftUI

/// Twin Pro unlock sheet. Purchase/restore run against StoreKit 2;
/// locally the product comes from Configuration.storekit.
struct PaywallView: View {
    @ObservedObject private var store = StoreKitManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: store.isProUnlocked ? "checkmark.seal.fill" : "lock.open")
                .font(.system(size: 40))
                .foregroundStyle(store.isProUnlocked ? Color.green : Color.accentColor)

            Text(store.isProUnlocked ? "Twin Pro is unlocked" : "Twin Pro")
                .font(.title2.bold())

            if store.isProUnlocked {
                Text("Workspaces, Folder Sync, Batch Rename and Git badges are available.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(TwinPro.features).sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { feature in
                        Label(feature.rawValue.capitalized, systemImage: "checkmark")
                    }
                }
                Text(store.product?.displayPrice ?? "249 kr")
                    .font(.title3.bold())
                Text("One-time. Lifetime + 1 year of updates.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await purchase() }
                } label: {
                    if store.purchaseInFlight {
                        ProgressView()
                    } else {
                        Text("Buy Twin Pro")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.purchaseInFlight)

                Button("Restore Purchases") {
                    Task { await restore() }
                }
                .disabled(store.purchaseInFlight)
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Close") { dismiss() }
        }
        .padding(24)
        .frame(width: 360)
        .task { await store.refresh() }
    }

    private func purchase() async {
        switch await store.purchase() {
        case .success: message = "Thank you — Twin Pro is unlocked."
        case .userCancelled: message = nil
        case .pending: message = "Purchase is pending approval."
        case .failed(let reason): message = "Purchase failed: \(reason)"
        }
    }

    private func restore() async {
        do {
            try await store.restorePurchases()
            message = store.isProUnlocked ? "Purchases restored." : "No previous purchase found."
        } catch {
            message = "Restore failed: \(error.localizedDescription)"
        }
    }
}
