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

    func testCorrectSegmentWithWrongReasonIsNotPerfect() {
        let question = makeChoiceOrSegmentQuestion(
            id: "reason-matters",
            responseType: .selectSegments,
            correctSegmentIds: ["s2"],
            recommendedReasonTags: [.urgency]
        )

        let evaluation = QuizScorer.evaluate(
            question: question,
            selectedSegmentIds: ["s2"],
            selectedReasonTags: [.noSource]
        )

        XCTAssertFalse(evaluation.result.isPerfect)
        XCTAssertEqual(evaluation.offTargetReasonTags, [.noSource])
        XCTAssertEqual(evaluation.missedRecommendedTags, [.urgency])
    }

    func testInsufficientInformationCanBeTheEvidenceBasedCorrectAnswer() {
        let question = makeChoiceOrSegmentQuestion(
            id: "insufficient",
            responseType: .singleChoice,
            answerChoices: [
                AnswerChoice(id: "safe", text: "安全", semantic: .noIssueFound),
                AnswerChoice(id: "unknown", text: "この情報だけでは判断できない", semantic: .insufficientInformation),
            ],
            correctChoiceId: "unknown"
        )

        let evaluation = QuizScorer.evaluate(
            question: question,
            selectedSegmentIds: [],
            selectedReasonTags: [],
            selectedChoiceId: "unknown"
        )

        XCTAssertTrue(evaluation.result.isPerfect)
        XCTAssertEqual(evaluation.correctChoice?.semantic, .insufficientInformation)
    }

    func testNoIssueFoundDoesNotMeanGuaranteedSafe() {
        let question = makeChoiceOrSegmentQuestion(
            id: "no-issue",
            responseType: .singleChoice,
            answerChoices: [
                AnswerChoice(id: "no-issue", text: "この文に問題は見当たらない", semantic: .noIssueFound),
                AnswerChoice(id: "guaranteed", text: "絶対に安全", semantic: .other),
            ],
            correctChoiceId: "no-issue"
        )

        let evaluation = QuizScorer.evaluate(
            question: question,
            selectedSegmentIds: [],
            selectedReasonTags: [],
            selectedChoiceId: "guaranteed"
        )

        XCTAssertFalse(evaluation.result.isPerfect)
        XCTAssertEqual(evaluation.correctChoice?.semantic, .noIssueFound)
    }

    func testHintAndRetryAreRecordedSeparatelyFromIndependentSuccess() {
        let question = makeChoiceOrSegmentQuestion(
            id: "hinted",
            responseType: .singleChoice,
            answerChoices: [
                AnswerChoice(id: "verify", text: "公式情報を確認する", semantic: .verifySource),
                AnswerChoice(id: "share", text: "すぐ共有する", semantic: .other),
            ],
            correctChoiceId: "verify"
        )

        let evaluation = QuizScorer.evaluate(
            question: question,
            selectedSegmentIds: [],
            selectedReasonTags: [],
            selectedChoiceId: "verify",
            hintUsed: true,
            attemptNumber: 2
        )

        XCTAssertTrue(evaluation.result.isPerfect)
        XCTAssertTrue(evaluation.result.hintUsed)
        XCTAssertEqual(evaluation.result.attemptNumber, 2)
        XCTAssertFalse(evaluation.result.isFirstTryIndependent)
        XCTAssertEqual(evaluation.result.score, 55)
    }

    private func makeChoiceOrSegmentQuestion(
        id: String,
        responseType: QuestionResponseType,
        correctSegmentIds: [String] = [],
        recommendedReasonTags: [ReasonTag] = [],
        answerChoices: [AnswerChoice] = [],
        correctChoiceId: String? = nil
    ) -> QuizQuestion {
        QuizQuestion(
            id: id,
            mode: .scamAdChecker,
            title: "テスト",
            difficulty: .easy,
            instruction: "考えてください。",
            segments: [
                TextSegment(id: "s1", text: "案内があります。", phoneticText: nil),
                TextSegment(id: "s2", text: "今日中に決めてください。", phoneticText: nil),
            ],
            correctSegmentIds: correctSegmentIds,
            explanation: "表現だけで嘘とは断定せず、根拠を確かめます。",
            verificationTip: "公式の案内や信頼できる別の人に確認します。",
            hint: "判断の根拠を探します。",
            recommendedReasonTags: recommendedReasonTags,
            learningStage: .challenge,
            learningFocus: .verify,
            responseType: responseType,
            answerChoices: answerChoices,
            correctChoiceId: correctChoiceId,
            attentionPoint: "判断できる材料があるかに注目します。"
        )
    }
}
