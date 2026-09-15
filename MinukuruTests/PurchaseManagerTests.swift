import XCTest
@testable import Minukuru

@MainActor
final class PurchaseManagerTests: XCTestCase {
    final class CounterBox {
        var value = 0

        func increment() {
            value += 1
        }
    }

    final class ActivityObservationBox {
        var isFetchingProducts = false
        var isPurchasing = true
        var isRestoring = true
    }

    func testAsyncTimeoutReturnsOperationValueWhenFinishedInTime() async throws {
        enum TimeoutError: Error, Sendable {
            case reached
        }

        let value = try await AsyncTimeout.run(timeout: 1_000_000_000, timedOutError: TimeoutError.reached) {
            42
        }

        XCTAssertEqual(value, 42)
    }

    func testAsyncTimeoutReturnsTimedOutErrorWhenOperationDoesNotFinish() async {
        enum TimeoutError: Error, Sendable {
            case reached
        }

        do {
            _ = try await AsyncTimeout.run(timeout: 1_000_000, timedOutError: TimeoutError.reached) {
                try await Task.sleep(nanoseconds: 100_000_000)
                return 42
            }
            XCTFail("Expected timeout to be thrown.")
        } catch TimeoutError.reached {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPrepareRetriesWhenStoreReturnsNoProducts() async {
        let requestCount = CounterBox()
        let manager = PurchaseManager(
            productRequest: { _ in
                requestCount.increment()
                return []
            },
            paymentCapabilityProvider: { true },
            pause: { _ in },
            productRetryDelays: [0, 0, 0],
            shouldObserveTransactionUpdates: false
        )

        await manager.prepare()

        XCTAssertEqual(requestCount.value, 3)
        XCTAssertEqual(manager.productFetchState, .unavailable)
        XCTAssertNil(manager.premiumProduct)
        XCTAssertEqual(
            manager.productFetchMessage,
            "App Storeでプレミアム商品がまだ見つかりません。設定の反映に時間がかかっていることがあります。しばらくしてから、もう一度確認してください。"
        )
    }

    func testPrepareRetriesWhenStoreRequestFails() async {
        enum TestError: Error {
            case offline
        }

        let requestCount = CounterBox()
        let manager = PurchaseManager(
            productRequest: { _ in
                requestCount.increment()
                throw TestError.offline
            },
            paymentCapabilityProvider: { true },
            pause: { _ in },
            productRetryDelays: [0, 0],
            shouldObserveTransactionUpdates: false
        )

        await manager.prepare()

        XCTAssertEqual(requestCount.value, 2)
        XCTAssertEqual(manager.productFetchState, .failed)
        XCTAssertNil(manager.premiumProduct)
        XCTAssertEqual(
            manager.productFetchMessage,
            "プレミアム情報の読み込みに失敗しました。時間をおいてもう一度お試しください。"
        )
        XCTAssertNotNil(manager.purchaseDebugDetail)
    }

    func testPrepareFailsFastWhenStoreRequestTimesOut() async {
        let requestCount = CounterBox()
        let manager = PurchaseManager(
            productRequest: { _ in
                requestCount.increment()
                try await Task.sleep(nanoseconds: 100_000_000)
                return []
            },
            paymentCapabilityProvider: { true },
            pause: { _ in },
            productRetryDelays: [0],
            productRequestTimeout: 1_000_000,
            shouldObserveTransactionUpdates: false
        )

        await manager.prepare()

        XCTAssertEqual(requestCount.value, 1)
        XCTAssertEqual(manager.productFetchState, .failed)
        XCTAssertNil(manager.premiumProduct)
        XCTAssertEqual(
            manager.productFetchMessage,
            "App Storeの応答に時間がかかっています。しばらくしてからもう一度読み込んでください。"
        )
        XCTAssertNotNil(manager.purchaseDebugDetail)
    }

    func testEnsurePremiumProductAvailableKeepsRetryingAcrossRefreshPasses() async {
        let requestCount = CounterBox()
        let manager = PurchaseManager(
            productRequest: { _ in
                requestCount.increment()
                return []
            },
            paymentCapabilityProvider: { true },
            pause: { _ in },
            productRetryDelays: [0],
            shouldObserveTransactionUpdates: false
        )

        await manager.ensurePremiumProductAvailable(maxRefreshPasses: 2, delayBetweenRefreshes: 0)

        XCTAssertEqual(requestCount.value, 3)
        XCTAssertEqual(manager.productFetchState, .unavailable)
        XCTAssertNil(manager.premiumProduct)
    }

    func testPrepareSeparatesProductFetchFromPurchaseLoading() async {
        var manager: PurchaseManager!
        let observedActivity = ActivityObservationBox()

        manager = PurchaseManager(
            productRequest: { _ in
                observedActivity.isFetchingProducts = manager.isFetchingProducts
                observedActivity.isPurchasing = manager.isPurchasing
                observedActivity.isRestoring = manager.isRestoring
                return []
            },
            paymentCapabilityProvider: { true },
            pause: { _ in },
            productRetryDelays: [0],
            shouldObserveTransactionUpdates: false
        )

        await manager.prepare()

        XCTAssertTrue(observedActivity.isFetchingProducts)
        XCTAssertFalse(observedActivity.isPurchasing)
        XCTAssertFalse(observedActivity.isRestoring)
        XCTAssertFalse(manager.isFetchingProducts)
        XCTAssertFalse(manager.isPurchasing)
        XCTAssertFalse(manager.isRestoring)
        XCTAssertFalse(manager.isLoading)
    }
}
