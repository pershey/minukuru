import XCTest
@testable import Minukuru

final class UserDefaultsStatsStoreTests: XCTestCase {
    func testRoundTripAndClear() {
        let defaults = UserDefaults(suiteName: "MinukuruTests-\(UUID().uuidString)")!
        let store = UserDefaultsStatsStore(defaults: defaults)
        let stats = UserStats(
            totalChallenges: 4,
            correctAnswers: 3,
            perfectAnswers: 1,
            currentStreak: 2,
            bestStreak: 3,
            totalScore: 120
        )
        let result = QuizResult(
            questionId: "exp-1",
            selectedSegmentIds: ["s3"],
            selectedReasonTags: [.gutFeeling],
            score: 55,
            isPerfect: true,
            answeredAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        store.save(stats: stats)
        store.save(results: [result])

        XCTAssertEqual(store.loadStats(), stats)
        XCTAssertEqual(store.loadResults(), [result])

        store.clearAll()

        XCTAssertEqual(store.loadStats(), UserStats())
        XCTAssertEqual(store.loadResults(), [])
    }
}
