import XCTest
@testable import Minukuru

final class UserDefaultsStatsStoreTests: XCTestCase {
    private struct LegacyQuizResult: Codable {
        let questionId: String
        let selectedSegmentIds: [String]
        let selectedReasonTags: [ReasonTag]
        let score: Int
        let isPerfect: Bool
        let answeredAt: Date
    }

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

    func testLoadsResultsWrittenBeforeLearningMetadataWasAdded() throws {
        let defaults = UserDefaults(suiteName: "MinukuruLegacyTests-\(UUID().uuidString)")!
        let store = UserDefaultsStatsStore(defaults: defaults)
        let legacy = LegacyQuizResult(
            questionId: "legacy-question",
            selectedSegmentIds: ["s1"],
            selectedReasonTags: [.noSource],
            score: 50,
            isPerfect: true,
            answeredAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        defaults.set(try JSONEncoder().encode([legacy]), forKey: "minukuru.quizResults")

        let loaded = try XCTUnwrap(store.loadResults().first)

        XCTAssertEqual(loaded.questionId, "legacy-question")
        XCTAssertEqual(loaded.responseType, .selectSegments)
        XCTAssertFalse(loaded.hintUsed)
        XCTAssertEqual(loaded.attemptNumber, 1)
        XCTAssertEqual(loaded.learningStage, .challenge)
        XCTAssertEqual(loaded.contentRevision, 1)
    }

    func testModeProgressCountsRetriedQuestionsOnlyOnce() {
        let question = QuizQuestion(
            id: "repeat-question",
            mode: .newsPoison,
            title: "同じ問題",
            difficulty: .normal,
            instruction: "考えてください。",
            segments: [TextSegment(id: "s1", text: "本文", phoneticText: nil)],
            correctSegmentIds: ["s1"],
            explanation: "理由",
            verificationTip: "確認方法",
            hint: "ヒント",
            recommendedReasonTags: [.noSource]
        )
        let firstAttempt = QuizResult(
            questionId: question.id,
            selectedSegmentIds: [],
            selectedReasonTags: [],
            score: 5,
            isPerfect: false,
            answeredAt: Date(timeIntervalSince1970: 1)
        )
        let retry = QuizResult(
            questionId: question.id,
            selectedSegmentIds: ["s1"],
            selectedReasonTags: [.noSource],
            score: 65,
            isPerfect: true,
            attemptNumber: 2,
            answeredAt: Date(timeIntervalSince1970: 2)
        )

        let summary = ModeProgressSummary.make(
            mode: .newsPoison,
            questions: [question],
            results: [firstAttempt, retry]
        )

        XCTAssertEqual(summary.answeredCount, 1)
        XCTAssertEqual(summary.totalCount, 1)
        XCTAssertEqual(summary.perfectCount, 1)
    }
}
