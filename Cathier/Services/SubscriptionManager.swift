import StoreKit

/// Manages the $4.99/month "No API Key" subscription.
///
/// App Store Connect setup required:
///   1. Create an Auto-Renewable Subscription group called "AI Access"
///   2. Add product ID: com.cathier.ai.managed.monthly  (price tier: $4.99 USD)
///   3. Enable In-App Purchases capability in Xcode (Signing & Capabilities)
@Observable
final class SubscriptionManager {

    static let shared = SubscriptionManager()

    /// Must match the product ID created in App Store Connect.
    static let productID = "com.cathier.ai.managed.monthly"

    private(set) var isSubscribed = false
    private(set) var product: Product?
    private(set) var isPurchasing = false
    private(set) var errorMessage: String?

    init() {
        Task { await loadProduct() }
        Task { await checkStatus() }
        // Listen for background transaction updates (renewals, refunds, etc.)
        Task {
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await tx.finish()
                    await checkStatus()
                }
            }
        }
    }

    // MARK: - Public API

    func purchase() async {
        // Load product on demand in case init's background task hasn't finished yet
        if product == nil { await loadProduct() }
        guard let product else {
            errorMessage = "Product unavailable. Check App Store Connect setup."
            return
        }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    await tx.finish()
                    await checkStatus()
                }
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await checkStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Formatted price

    /// e.g. "$4.99" — falls back to "$4.99" if product hasn't loaded yet
    var displayPrice: String {
        product?.displayPrice ?? "$4.99"
    }

    // MARK: - Internal

    private func loadProduct() async {
        guard let products = try? await Product.products(for: [Self.productID]) else { return }
        product = products.first
    }

    func checkStatus() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            if tx.productID == Self.productID && tx.revocationDate == nil {
                active = true
            }
        }
        isSubscribed = active
    }
}
