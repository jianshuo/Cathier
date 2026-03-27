import StoreKit

/// Manages the $4.99/month "No API Key" subscription.
///
/// App Store Connect setup required:
///   1. Create an Auto-Renewable Subscription group called "AI Access"
///   2. Add product ID: com.wangjianshuo.cathier.ai.managed.monthly  (price tier: $4.99 USD)
///   3. Enable In-App Purchases capability in Xcode (Signing & Capabilities)
@Observable
final class SubscriptionManager {

    static let shared = SubscriptionManager()

    /// Must match the product ID created in App Store Connect.
    static let productID = "com.wangjianshuo.cathier.ai.managed.monthly"

    private(set) var isSubscribed = false
    private(set) var product: Product?
    private(set) var isPurchasing = false
    private(set) var errorMessage: String?

    init() {
        t("SubscriptionManager.init() — START")
        Task {
            t("StoreKit loadProduct() — START")
            await loadProduct()
            t("StoreKit loadProduct() — END")
        }
        Task {
            t("StoreKit checkStatus() — START")
            await checkStatus()
            t("StoreKit checkStatus() — END")
        }
        // Listen for background transaction updates (renewals, refunds, etc.)
        Task {
            t("StoreKit Transaction.updates loop — START")
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await tx.finish()
                    await checkStatus()
                }
            }
        }
        t("SubscriptionManager.init() — END (tasks queued)")
    }

    // MARK: - Public API

    func purchase() async {
        print("[Sub] purchase() tapped")
        // Load product on demand in case init's background task hasn't finished yet
        if product == nil {
            print("[Sub] product is nil, calling loadProduct()")
            await loadProduct()
        }
        guard let product else {
            print("[Sub] ❌ Still no product after loadProduct() — aborting purchase")
            errorMessage = "Product unavailable. Check App Store Connect setup."
            return
        }
        print("[Sub] Calling product.purchase() for \(product.id)")
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                print("[Sub] purchase .success, verification: \(verification)")
                if case .verified(let tx) = verification {
                    print("[Sub] ✅ Transaction verified: \(tx.productID)")
                    await tx.finish()
                    await checkStatus()
                } else {
                    print("[Sub] ⚠️ Transaction unverified")
                    errorMessage = "Purchase could not be verified."
                }
            case .userCancelled:
                print("[Sub] User cancelled purchase")
            case .pending:
                print("[Sub] Purchase pending (e.g. Ask to Buy)")
            @unknown default:
                print("[Sub] Unknown purchase result")
            }
        } catch {
            print("[Sub] ❌ purchase() error: \(error)")
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
        print("[Sub] loadProduct() called for \(Self.productID)")
        do {
            let products = try await Product.products(for: [Self.productID])
            print("[Sub] StoreKit returned \(products.count) product(s): \(products.map(\.id))")
            product = products.first
            if product == nil {
                print("[Sub] ⚠️ No product found — check product ID in App Store Connect / .storekit config")
            } else {
                print("[Sub] ✅ Product loaded: \(product!.displayName) \(product!.displayPrice)")
            }
        } catch {
            print("[Sub] ❌ loadProduct error: \(error)")
        }
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
