import XCTest
@testable import Minukuru

final class LearningQuestionContentTests: XCTestCase {
    func testBundledLearningSetContainsRepresentativeChildAndAdultFlows() {
        let questions = FileQuizContentStore()
            .loadBundledManifest(from: .main)
            .questions
            .filter { $0.id.hasPrefix("core-") }

        XCTAssertGreaterThanOrEqual(questions.filter { $0.audience == .child }.count, 10)
        XCTAssertGreaterThanOrEqual(questions.filter { $0.audience == .adult }.count, 3)
        XCTAssertTrue(questions.contains { $0.learningStage == .example })
        XCTAssertTrue(questions.contains { $0.learningStage == .practice })
        XCTAssertTrue(questions.contains { $0.learningStage == .action })
        XCTAssertTrue(questions.contains { $0.learningStage == .challenge })
        XCTAssertTrue(questions.contains { question in
            question.answerChoices.contains { $0.semantic == .insufficientInformation }
        })
        XCTAssertTrue(questions.contains { question in
            question.answerChoices.contains { $0.semantic == .noIssueFound }
        })
    }

    func testBundledLearningQuestionsHaveConsistentAnswersAndExplanations() {
        let questions = FileQuizContentStore()
            .loadBundledManifest(from: .main)
            .questions
            .filter { $0.id.hasPrefix("core-") }

        XCTAssertFalse(questions.isEmpty)
        for question in questions {
            XCTAssertFalse(question.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, question.id)
            XCTAssertFalse(question.verificationTip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, question.id)
            XCTAssertFalse(question.displayAttentionPoint(isHiraganaMode: false).isEmpty, question.id)

            switch question.responseType {
            case .selectSegments:
                let segmentIDs = Set(question.segments.map(\.id))
                XCTAssertFalse(question.correctSegmentIds.isEmpty, question.id)
                XCTAssertTrue(Set(question.correctSegmentIds).isSubset(of: segmentIDs), question.id)
            case .singleChoice:
                XCTAssertGreaterThanOrEqual(question.answerChoices.count, 2, question.id)
                XCTAssertNotNil(question.correctChoiceId, question.id)
                XCTAssertTrue(question.answerChoices.contains { $0.id == question.correctChoiceId }, question.id)
                XCTAssertTrue(question.correctSegmentIds.isEmpty, question.id)
            }
        }
    }
}
