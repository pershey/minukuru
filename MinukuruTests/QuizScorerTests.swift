import XCTest
@testable import Minukuru

final class QuizScorerTests: XCTestCase {
    func testPerfectAnswerGetsBonus() {
        let question = QuizQuestion(
            id: "test",
            mode: .explanationSnipe,
            title: "テスト",
            difficulty: .easy,
            instruction: "1こ選んでね",
            phoneticInstruction: nil,
            segments: [
                TextSegment(id: "s1", text: "あやしい", phoneticText: nil),
                TextSegment(id: "s2", text: "ふつう", phoneticText: nil)
            ],
            correctSegmentIds: ["s1"],
            explanation: "説明",
            phoneticExplanation: nil,
            verificationTip: "確認",
            phoneticVerificationTip: nil,
            hint: "ヒント",
            phoneticHint: nil,
            phoneticTitle: nil,
            recommendedReasonTags: [.gutFeeling, .tooStrongClaim],
            authorName: nil,
            authorId: nil,
            reviewStatus: nil,
            reportCount: nil,
            educationalScore: nil,
            safetyLevel: nil,
            createdAt: nil,
            updatedAt: nil
        )

        let evaluation = QuizScorer.evaluate(
            question: question,
            selectedSegmentIds: ["s1"],
            selectedReasonTags: [.gutFeeling]
        )

        XCTAssertTrue(evaluation.result.isPerfect)
        XCTAssertEqual(evaluation.result.score, 65)
        XCTAssertTrue(evaluation.missedSegments.isEmpty)
        XCTAssertTrue(evaluation.wrongSegments.isEmpty)
        XCTAssertEqual(evaluation.matchedReasonTags, [.gutFeeling])
        XCTAssertEqual(evaluation.missedRecommendedTags, [.tooStrongClaim])
        XCTAssertTrue(evaluation.offTargetReasonTags.isEmpty)
    }

    func testWrongSelectionStillKeepsMinimumLearningScore() {
        let question = QuizQuestion(
            id: "test-2",
            mode: .newsPoison,
            title: "テスト2",
            difficulty: .normal,
            instruction: "選んでね",
            phoneticInstruction: nil,
            segments: [
                TextSegment(id: "s1", text: "ふつう", phoneticText: nil),
                TextSegment(id: "s2", text: "あやしい", phoneticText: nil)
            ],
            correctSegmentIds: ["s2"],
            explanation: "説明",
            phoneticExplanation: nil,
            verificationTip: "確認",
            phoneticVerificationTip: nil,
            hint: "ヒント",
            phoneticHint: nil,
            phoneticTitle: nil,
            recommendedReasonTags: [.noSource],
            authorName: nil,
            authorId: nil,
            reviewStatus: nil,
            reportCount: nil,
            educationalScore: nil,
            safetyLevel: nil,
            createdAt: nil,
            updatedAt: nil
        )

        let evaluation = QuizScorer.evaluate(
            question: question,
            selectedSegmentIds: ["s1"],
            selectedReasonTags: []
        )

        XCTAssertFalse(evaluation.result.isPerfect)
        XCTAssertEqual(evaluation.result.score, 5)
        XCTAssertEqual(evaluation.missedSegments.map(\.id), ["s2"])
        XCTAssertEqual(evaluation.wrongSegments.map(\.id), ["s1"])
        XCTAssertTrue(evaluation.matchedReasonTags.isEmpty)
        XCTAssertEqual(evaluation.missedRecommendedTags, [.noSource])
    }
}
