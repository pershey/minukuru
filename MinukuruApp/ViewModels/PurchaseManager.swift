import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    enum ProductFetchState: Equatable {
        case idle
        case loading
        case loaded
        case unavailable
        case failed
    }

    @Published private(set) var premiumProduct: Product?
    @Published private(set) var hasPremiumAccess = false
    @Published private(set) var isLoading = false
    @Published private(set) var purchaseMessage: String?
    @Published private(set) var purchaseDebugDetail: String?
    @Published private(set) var productFetchState: ProductFetchState = .idle
    @Published private(set) var productFetchMessage: String?
    @Published private(set) var storeDiagnostics: [String] = []
    @Published private(set) var canMakePayments = SKPaymentQueue.canMakePayments()
    @Published private(set) var lastStoreSyncAt: Date?

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

    func reloadStoreState() async {
        purchaseMessage = nil
        await prepare()
        if premiumProduct == nil, purchaseMessage == nil {
            purchaseMessage = productFetchMessage
        }
    }

    func purchasePremium() async {
        purchaseMessage = nil
        purchaseDebugDetail = nil

        if premiumProduct == nil {
            await requestProducts()
        }

        guard canMakePayments else {
            purchaseMessage = "この端末ではアプリ内課金が制限されています。"
            purchaseDebugDetail = "設定アプリのスクリーンタイムや購入制限を確認してください。"
            return
        }

        guard let premiumProduct else {
            purchaseMessage = productFetchMessage ?? "商品情報を読み込み中です。少し待ってもう一度お試しください。"
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
            purchaseMessage = "購入に失敗しました。もう一度お試しください。"
            purchaseDebugDetail = describe(error)
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
        canMakePayments = SKPaymentQueue.canMakePayments()
        lastStoreSyncAt = Date()
        purchaseDebugDetail = nil
        storeDiagnostics = [
            "商品ID: \(MonetizationConfig.premiumProductID)",
            "課金制限: \(canMakePayments ? "なし" : "あり")"
        ]

        guard canMakePayments else {
            premiumProduct = nil
            productFetchState = .unavailable
            productFetchMessage = "この端末ではアプリ内課金が使えません。"
            return
        }

        productFetchState = .loading

        do {
            let storeProducts = try await Product.products(for: [MonetizationConfig.premiumProductID])
            premiumProduct = storeProducts.first
            storeDiagnostics.append("取得件数: \(storeProducts.count)件")

            if let premiumProduct {
                productFetchState = .loaded
                productFetchMessage = "商品情報を読み込みました。"
                storeDiagnostics.append("商品名: \(premiumProduct.displayName)")
                storeDiagnostics.append("価格: \(premiumProduct.displayPrice)")
            } else {
                productFetchState = .unavailable
                productFetchMessage = "商品情報がまだ取得できません。App Store Connect 側の設定反映待ちの可能性があります。"
                storeDiagnostics.append("App Store Connect で商品が配信されていないか、反映待ちの可能性があります。")
            }
        } catch {
            premiumProduct = nil
            productFetchState = .failed
            productFetchMessage = "商品情報の取得に失敗しました。"
            purchaseDebugDetail = describe(error)
            storeDiagnostics.append("取得エラー: \(describe(error))")
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

    private func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain) (\(nsError.code)): \(nsError.localizedDescription)"
    }
}

enum StoreError: Error {
    case failedVerification
}
