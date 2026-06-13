import XCTest
@testable import Minukuru

final class QuestionAccessPolicyTests: XCTestCase {
    func testFreePlanShowsOnlyFreeStandardQuestionsUpToLimit() {
        let questions = [
            makeQuestion(id: "free-1", accessTier: .free, contentFlavor: .standard),
            makeQuestion(id: "free-2", accessTier: .free, contentFlavor: .standard),
            makeQuestion(id: "premium-1", accessTier: .premium, contentFlavor: .standard),
            makeQuestion(id: "real-1", accessTier: .premium, contentFlavor: .realWorld)
        ]

        let policy = QuestionAccessPolicy(freeQuestionLimit: 2)
        let visible = policy.visibleQuestions(from: questions, settings: AppSettings(), hasPremiumAccess: false)

        XCTAssertEqual(visible.map(\.id), ["free-1", "free-2"])
    }

    func testPremiumRealityModeAddsRealWorldQuestions() {
        let questions = [
            makeQuestion(id: "free-1", accessTier: .free, contentFlavor: .standard),
            makeQuestion(id: "premium-1", accessTier: .premium, contentFlavor: .standard),
            makeQuestion(id: "real-1", accessTier: .premium, contentFlavor: .realWorld)
        ]

        let policy = QuestionAccessPolicy()
        let premiumStandard = policy.visibleQuestions(
            from: questions,
            settings: AppSettings(isRealityModeEnabled: false),
            hasPremiumAccess: true
        )
        let premiumReality = policy.visibleQuestions(
            from: questions,
            settings: AppSettings(isRealityModeEnabled: true),
            hasPremiumAccess: true
        )

        XCTAssertEqual(premiumStandard.map(\.id), ["free-1", "premium-1"])
        XCTAssertEqual(premiumReality.map(\.id), ["free-1", "premium-1", "real-1"])
    }

    func testSkipAnsweredPrefersFirstUnansweredQuestion() {
        let questions = [
            makeQuestion(id: "q1"),
            makeQuestion(id: "q2"),
            makeQuestion(id: "q3")
        ]

        let policy = QuestionAccessPolicy()
        let next = policy.nextQuestion(
            from: questions,
            progressIndex: 2,
            answeredQuestionIDs: ["q1", "q3"],
            skipAnswered: true
        )

        XCTAssertEqual(next?.id, "q2")
    }

    private func makeQuestion(
        id: String,
        accessTier: AccessTier = .free,
        contentFlavor: ContentFlavor = .standard
    ) -> QuizQuestion {
        QuizQuestion(
            id: id,
            mode: .newsPoison,
            title: id,
            difficulty: .easy,
            instruction: "あやしいところを見つけよう",
            segments: [
                TextSegment(id: "\(id)-1", text: "本文です。", phoneticText: nil)
            ],
            correctSegmentIds: ["\(id)-1"],
            explanation: "解説",
            verificationTip: "確認",
            hint: "ヒント",
            recommendedReasonTags: [.gutFeeling],
            accessTier: accessTier,
            contentFlavor: contentFlavor
        )
    }
}
