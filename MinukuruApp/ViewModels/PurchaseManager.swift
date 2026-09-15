import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    typealias ProductRequest = @MainActor @Sendable ([String]) async throws -> [Product]
    typealias PaymentCapabilityProvider = @MainActor @Sendable () -> Bool
    typealias PauseProvider = @MainActor @Sendable (UInt64) async -> Void

    enum ProductFetchState: Equatable {
        case idle
        case loading
        case loaded
        case unavailable
        case failed
    }

    @Published private(set) var premiumProduct: Product?
    @Published private(set) var hasPremiumAccess = false
    @Published private(set) var premiumEntitlementJWS: String?
    @Published private(set) var isFetchingProducts = false
    @Published private(set) var isRefreshingEntitlements = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published private(set) var purchaseMessage: String?
    @Published private(set) var purchaseDebugDetail: String?
    @Published private(set) var productFetchState: ProductFetchState = .idle
    @Published private(set) var productFetchMessage: String?
    @Published private(set) var storeDiagnostics: [String] = []
    @Published private(set) var canMakePayments: Bool
    @Published private(set) var lastStoreSyncAt: Date?

    private var updatesTask: Task<Void, Never>?
    private var activeProductRequestCount = 0
    private var activeEntitlementRefreshCount = 0
    private var activePurchaseCount = 0
    private var activeRestoreCount = 0
    private let productRequest: ProductRequest
    private let paymentCapabilityProvider: PaymentCapabilityProvider
    private let pause: PauseProvider
    private let productRetryDelays: [UInt64]
    private let productRequestTimeout: UInt64
    private let purchaseTimeout: UInt64
    private let restoreTimeout: UInt64
    private let entitlementRefreshTimeout: UInt64

    init(
        productRequest: @escaping ProductRequest = { try await Product.products(for: $0) },
        paymentCapabilityProvider: @escaping PaymentCapabilityProvider = { SKPaymentQueue.canMakePayments() },
        pause: @escaping PauseProvider = { nanoseconds in
            try? await Task.sleep(nanoseconds: nanoseconds)
        },
        productRetryDelays: [UInt64] = [0, 1_000_000_000, 3_000_000_000],
        productRequestTimeout: UInt64 = 8_000_000_000,
        purchaseTimeout: UInt64 = 30_000_000_000,
        restoreTimeout: UInt64 = 15_000_000_000,
        entitlementRefreshTimeout: UInt64 = 8_000_000_000,
        shouldObserveTransactionUpdates: Bool = true
    ) {
        self.productRequest = productRequest
        self.paymentCapabilityProvider = paymentCapabilityProvider
        self.pause = pause
        self.productRetryDelays = productRetryDelays
        self.productRequestTimeout = productRequestTimeout
        self.purchaseTimeout = purchaseTimeout
        self.restoreTimeout = restoreTimeout
        self.entitlementRefreshTimeout = entitlementRefreshTimeout
        self.canMakePayments = paymentCapabilityProvider()
        if shouldObserveTransactionUpdates {
            updatesTask = observeTransactionUpdates()
        }
    }

    var isLoading: Bool {
        isFetchingProducts || isRefreshingEntitlements || isPurchasing || isRestoring
    }

    deinit {
        updatesTask?.cancel()
    }

    func prepare() async {
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

    func ensurePremiumProductAvailable(
        maxRefreshPasses: Int = 3,
        delayBetweenRefreshes: UInt64 = 5_000_000_000
    ) async {
        guard !hasPremiumAccess else { return }

        if premiumProduct == nil, productFetchState != .loading {
            await reloadStoreState()
        }

        guard premiumProduct == nil else { return }

        for pass in 0..<maxRefreshPasses {
            await pause(delayBetweenRefreshes)
            guard !hasPremiumAccess, premiumProduct == nil else { return }

            if productFetchState != .loading {
                await reloadStoreState()
            }

            if pass == maxRefreshPasses - 1, premiumProduct == nil {
                purchaseMessage = productFetchMessage
            }
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

        beginActivity(.purchase)
        defer { endActivity(.purchase) }

        do {
            let result = try await withTimeout(purchaseTimeout, timedOutError: .purchaseTimedOut) {
                try await premiumProduct.purchase()
            }

            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                premiumEntitlementJWS = verification.jwsRepresentation
                await transaction.finish()
                hasPremiumAccess = true
                Task { @MainActor [weak self] in
                    await self?.refreshEntitlements()
                }
                purchaseMessage = "プレミアム機能が使えるようになりました。"
            case .userCancelled:
                purchaseMessage = "購入はキャンセルされました。"
            case .pending:
                purchaseMessage = "購入処理を確認中です。"
            @unknown default:
                purchaseMessage = "購入結果を確認できませんでした。"
            }
        } catch StoreError.purchaseTimedOut {
            purchaseMessage = "App Storeからの応答に時間がかかっています。少し待ってもう一度お試しください。"
            purchaseDebugDetail = "Purchase request timed out after \(purchaseTimeout / 1_000_000_000)s."
        } catch {
            purchaseMessage = "購入に失敗しました。もう一度お試しください。"
            purchaseDebugDetail = describe(error)
        }
    }

    func restorePurchases() async {
        beginActivity(.restore)
        defer { endActivity(.restore) }

        do {
            try await withTimeout(restoreTimeout, timedOutError: .restoreTimedOut) {
                try await AppStore.sync()
            }
            await refreshEntitlements()
            purchaseMessage = hasPremiumAccess
                ? "購入情報を復元しました。"
                : "復元できる購入が見つかりませんでした。"
        } catch StoreError.restoreTimedOut {
            purchaseMessage = "復元の確認に時間がかかっています。少し待ってからもう一度お試しください。"
        } catch {
            purchaseMessage = "購入情報の復元に失敗しました。"
        }
    }

    private func requestProducts() async {
        beginActivity(.productRequest)
        defer { endActivity(.productRequest) }

        canMakePayments = paymentCapabilityProvider()
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

        var lastError: Error?

        for (index, delay) in productRetryDelays.enumerated() {
            if delay > 0 {
                await pause(delay)
            }

            do {
                let storeProducts = try await withTimeout(productRequestTimeout, timedOutError: .productRequestTimedOut) { [productRequest] in
                    try await productRequest([MonetizationConfig.premiumProductID])
                }
                premiumProduct = storeProducts.first
                storeDiagnostics.append("取得試行 \(index + 1)回目: \(storeProducts.count)件")

                if let premiumProduct {
                    productFetchState = .loaded
                    productFetchMessage = "プレミアム情報を読み込みました。"
                    storeDiagnostics.append("商品名: \(premiumProduct.displayName)")
                    storeDiagnostics.append("価格: \(premiumProduct.displayPrice)")
                    return
                }
            } catch {
                lastError = error
                if case StoreError.productRequestTimedOut = error {
                    storeDiagnostics.append("取得試行 \(index + 1)回目でタイムアウト")
                } else {
                    storeDiagnostics.append("取得試行 \(index + 1)回目でエラー")
                }
            }
        }

        premiumProduct = nil

        if let lastError {
            productFetchState = .failed
            if case StoreError.productRequestTimedOut = lastError {
                productFetchMessage = "App Storeの応答に時間がかかっています。しばらくしてからもう一度読み込んでください。"
                purchaseDebugDetail = "Product request timed out after \(productRequestTimeout / 1_000_000_000)s."
                storeDiagnostics.append("取得タイムアウト: \(productRequestTimeout / 1_000_000_000)s")
            } else {
                productFetchMessage = "プレミアム情報の読み込みに失敗しました。時間をおいてもう一度お試しください。"
                purchaseDebugDetail = describe(lastError)
                storeDiagnostics.append("取得エラー: \(describe(lastError))")
            }
        } else {
            productFetchState = .unavailable
            productFetchMessage = "App Storeでプレミアム商品がまだ見つかりません。設定の反映に時間がかかっていることがあります。しばらくしてから、もう一度確認してください。"
            storeDiagnostics.append("商品取得結果: 0件")
            storeDiagnostics.append("App Storeから対象商品が返っていません")
        }
    }

    private func refreshEntitlements() async {
        beginActivity(.entitlementRefresh)
        defer { endActivity(.entitlementRefresh) }

        var hasPremium = false
        var entitlementJWS: String?

        do {
            let entitlement = try await withTimeout(
                entitlementRefreshTimeout,
                timedOutError: .entitlementRefreshTimedOut
            ) {
                var hasPremium = false
                var entitlementJWS: String?

                for await result in Transaction.currentEntitlements {
                    guard let transaction = try? Self.checkVerified(result) else { continue }
                    if transaction.productID == MonetizationConfig.premiumProductID {
                        hasPremium = true
                        entitlementJWS = result.jwsRepresentation
                    }
                }

                return (hasPremium, entitlementJWS)
            }
            hasPremium = entitlement.0
            entitlementJWS = entitlement.1
        } catch StoreError.entitlementRefreshTimedOut {
            storeDiagnostics.append("権利確認タイムアウト: \(entitlementRefreshTimeout / 1_000_000_000)s")
            purchaseDebugDetail = purchaseDebugDetail ?? "Entitlement refresh timed out after \(entitlementRefreshTimeout / 1_000_000_000)s."
            return
        } catch {
            storeDiagnostics.append("権利確認エラー: \(describe(error))")
            purchaseDebugDetail = purchaseDebugDetail ?? describe(error)
            return
        }

        premiumEntitlementJWS = hasPremium ? entitlementJWS : nil
        hasPremiumAccess = hasPremium
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                if let transaction = try? Self.checkVerified(result) {
                    if transaction.productID == MonetizationConfig.premiumProductID {
                        premiumEntitlementJWS = result.jwsRepresentation
                    }
                    await transaction.finish()
                }
                await refreshEntitlements()
            }
        }
    }

    nonisolated private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
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

    private func withTimeout<T: Sendable>(
        _ timeout: UInt64,
        timedOutError: StoreError,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await AsyncTimeout.run(
            timeout: timeout,
            timedOutError: timedOutError,
            operation: operation
        )
    }

    private func beginActivity(_ activity: Activity) {
        updateActivity(activity, delta: 1)
    }

    private func endActivity(_ activity: Activity) {
        updateActivity(activity, delta: -1)
    }

    private func updateActivity(_ activity: Activity, delta: Int) {
        switch activity {
        case .productRequest:
            activeProductRequestCount = max(0, activeProductRequestCount + delta)
            isFetchingProducts = activeProductRequestCount > 0
        case .entitlementRefresh:
            activeEntitlementRefreshCount = max(0, activeEntitlementRefreshCount + delta)
            isRefreshingEntitlements = activeEntitlementRefreshCount > 0
        case .purchase:
            activePurchaseCount = max(0, activePurchaseCount + delta)
            isPurchasing = activePurchaseCount > 0
        case .restore:
            activeRestoreCount = max(0, activeRestoreCount + delta)
            isRestoring = activeRestoreCount > 0
        }
    }
}

private extension PurchaseManager {
    enum Activity {
        case productRequest
        case entitlementRefresh
        case purchase
        case restore
    }
}

enum StoreError: Error, Sendable {
    case failedVerification
    case productRequestTimedOut
    case purchaseTimedOut
    case restoreTimedOut
    case entitlementRefreshTimedOut
}

enum AsyncTimeout {
    private actor ResolutionBox<Value: Sendable> {
        private var isResolved = false

        func resolve(
            _ result: Result<Value, Error>,
            continuation: CheckedContinuation<Value, Error>
        ) {
            guard !isResolved else { return }
            isResolved = true
            continuation.resume(with: result)
        }
    }

    static func run<Value: Sendable, TimeoutError: Error & Sendable>(
        timeout: UInt64,
        timedOutError: TimeoutError,
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        let operationTask = Task<Value, Error> {
            try await operation()
        }
        let timeoutTask = Task<Value, Error> {
            try await Task.sleep(nanoseconds: timeout)
            throw timedOutError
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let resolutionBox = ResolutionBox<Value>()

                Task {
                    do {
                        let value = try await operationTask.value
                        await resolutionBox.resolve(.success(value), continuation: continuation)
                    } catch {
                        await resolutionBox.resolve(.failure(error), continuation: continuation)
                    }
                    timeoutTask.cancel()
                }

                Task {
                    do {
                        let value = try await timeoutTask.value
                        await resolutionBox.resolve(.success(value), continuation: continuation)
                    } catch {
                        await resolutionBox.resolve(.failure(error), continuation: continuation)
                    }
                    operationTask.cancel()
                }
            }
        } onCancel: {
            operationTask.cancel()
            timeoutTask.cancel()
        }
    }
}
