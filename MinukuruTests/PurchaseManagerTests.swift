import XCTest
@testable import Minukuru

@MainActor
final class PurchaseManagerTests: XCTestCase {
    func testPrepareRetriesWhenStoreReturnsNoProducts() async {
        var requestCount = 0
        let manager = PurchaseManager(
            productRequest: { _ in
                requestCount += 1
                return []
            },
            paymentCapabilityProvider: { true },
            pause: { _ in },
            productRetryDelays: [0, 0, 0],
            shouldObserveTransactionUpdates: false
        )

        await manager.prepare()

        XCTAssertEqual(requestCount, 3)
        XCTAssertEqual(manager.productFetchState, .unavailable)
        XCTAssertNil(manager.premiumProduct)
        XCTAssertEqual(
            manager.productFetchMessage,
            "プレミアム情報の準備に少し時間がかかっています。もう一度読み込むと改善することがあります。"
        )
    }

    func testPrepareRetriesWhenStoreRequestFails() async {
        enum TestError: Error {
            case offline
        }

        var requestCount = 0
        let manager = PurchaseManager(
            productRequest: { _ in
                requestCount += 1
                throw TestError.offline
            },
            paymentCapabilityProvider: { true },
            pause: { _ in },
            productRetryDelays: [0, 0],
            shouldObserveTransactionUpdates: false
        )

        await manager.prepare()

        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(manager.productFetchState, .failed)
        XCTAssertNil(manager.premiumProduct)
        XCTAssertEqual(
            manager.productFetchMessage,
            "プレミアム情報の読み込みに失敗しました。時間をおいてもう一度お試しください。"
        )
        XCTAssertNotNil(manager.purchaseDebugDetail)
    }

    func testEnsurePremiumProductAvailableKeepsRetryingAcrossRefreshPasses() async {
        var requestCount = 0
        let manager = PurchaseManager(
            productRequest: { _ in
                requestCount += 1
                return []
            },
            paymentCapabilityProvider: { true },
            pause: { _ in },
            productRetryDelays: [0],
            shouldObserveTransactionUpdates: false
        )

        await manager.ensurePremiumProductAvailable(maxRefreshPasses: 2, delayBetweenRefreshes: 0)

        XCTAssertEqual(requestCount, 3)
        XCTAssertEqual(manager.productFetchState, .unavailable)
        XCTAssertNil(manager.premiumProduct)
    }
}
