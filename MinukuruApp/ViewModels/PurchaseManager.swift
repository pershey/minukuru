import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var premiumProduct: Product?
    @Published private(set) var hasPremiumAccess = false
    @Published private(set) var isLoading = false
    @Published private(set) var purchaseMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = observeTransactionUpdates()
    }

    deinit {
        updatesTask?.cancel()
    }

    func prepare() async {
        isLoading = true
        defer { isLoading = false }

        await requestProducts()
        await refreshEntitlements()
    }

    func purchasePremium() async {
        guard let premiumProduct else {
            purchaseMessage = "商品情報を読み込み中です。少し待ってもう一度お試しください。"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await premiumProduct.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                purchaseMessage = "プレミアム機能が使えるようになりました。"
            case .userCancelled:
                purchaseMessage = "購入はキャンセルされました。"
            case .pending:
                purchaseMessage = "購入処理を確認中です。"
            @unknown default:
                purchaseMessage = "購入結果を確認できませんでした。"
            }
        } catch {
            purchaseMessage = "購入に失敗しました。通信状況を確認して、もう一度お試しください。"
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseMessage = hasPremiumAccess
                ? "購入情報を復元しました。"
                : "復元できる購入が見つかりませんでした。"
        } catch {
            purchaseMessage = "購入情報の復元に失敗しました。"
        }
    }

    private func requestProducts() async {
        do {
            let storeProducts = try await Product.products(for: [MonetizationConfig.premiumProductID])
            premiumProduct = storeProducts.first
        } catch {
            premiumProduct = nil
        }
    }

    private func refreshEntitlements() async {
        var hasPremium = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.productID == MonetizationConfig.premiumProductID {
                hasPremium = true
            }
        }

        hasPremiumAccess = hasPremium
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                if let transaction = try? checkVerified(result) {
                    await transaction.finish()
                }
                await refreshEntitlements()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreError.failedVerification
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
