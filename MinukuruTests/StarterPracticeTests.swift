import XCTest
@testable import Minukuru

final class StarterPracticeTests: XCTestCase {
    func testStarterUsesAdoptedOrderAndKeepsThreeDifferentDecisions() throws {
        let curriculum = try XCTUnwrap(FileQuizContentStore().loadBundledCurriculum(from: .main)).questions
        let first = try XCTUnwrap(StarterPractice.next(in: curriculum, results: []))
        let second = try XCTUnwrap(StarterPractice.next(in: curriculum, results: [answer(first.id)]))
        let third = try XCTUnwrap(StarterPractice.next(in: curriculum, results: [answer(first.id), answer(second.id)]))
        XCTAssertEqual([first.id, second.id, third.id], StarterPractice.questionIDs)
        XCTAssertEqual(first.answerChoices.first { $0.id == first.correctChoiceId }?.semantic, .noIssueFound)
        XCTAssertEqual(second.answerChoices.first { $0.id == second.correctChoiceId }?.semantic, .insufficientInformation)
        XCTAssertEqual(third.responseType, .selectSegments)
        XCTAssertEqual(third.correctSegmentIds, ["s2", "s4"])
        for question in [first, second, third] {
            XCTAssertFalse(question.phoneticTitle?.isEmpty ?? true)
            XCTAssertTrue(question.displayedSegments.allSatisfy { $0.phoneticText != nil })
            XCTAssertTrue(question.answerChoices.allSatisfy { $0.phoneticText != nil })
        }
    }

    func testOnlyThirdNewGradedResultAfterStarterCanShowAd() {
        let starters = StarterPractice.questionIDs.map { answer($0) }
        let a = answer("practice-a")
        let b = answer("practice-b")
        let retry = answer("practice-b", attempt: 2)
        let example = answer("example", stage: .example)
        let c = answer("practice-c")
        XCTAssertFalse(StarterPractice.endsAdEligibleSet(for: starters[2], history: starters))
        XCTAssertFalse(StarterPractice.endsAdEligibleSet(for: c, history: [starters[0], starters[1], a, b, c]))
        XCTAssertFalse(StarterPractice.endsAdEligibleSet(for: retry, history: starters + [a, b, retry]))
        XCTAssertFalse(StarterPractice.endsAdEligibleSet(for: example, history: starters + [a, b, example]))
        XCTAssertTrue(StarterPractice.endsAdEligibleSet(for: c, history: starters + [a, b, retry, example, c]))
    }

    func testLegacyOrderChangesPositionsWithoutChangingCorrectIDs() throws {
        let questions = FileQuizContentStore().loadBundledManifest(from: .main).questions
        let oldNews = questions.filter { $0.id.hasPrefix("newsPoison_") }
        XCTAssertEqual(oldNews.count, 10)
        var positions: [Int: Int] = [:]
        for question in oldNews {
            let position = try XCTUnwrap(question.displayedSegments.firstIndex { question.correctSegmentIds.contains($0.id) }) + 1
            positions[position, default: 0] += 1
            XCTAssertEqual(Set(question.segments), Set(question.displayedSegments))
        }
        XCTAssertEqual(positions, [2: 5, 3: 4, 4: 1])
        let free = QuestionAccessPolicy().visibleQuestions(from: questions, settings: .init(), hasPremiumAccess: false)
        XCTAssertEqual(free.count, 50)
        XCTAssertFalse(free.contains { $0.id == "scamAdChecker_011" || $0.id == "scamAdChecker_014" })
    }

    private func answer(_ id: String, attempt: Int = 1, stage: LearningStage = .practice) -> QuizResult {
        QuizResult(questionId: id, selectedSegmentIds: [], selectedReasonTags: [], score: 5, isPerfect: false,
                   attemptNumber: attempt, learningStage: stage, answeredAt: .now)
    }
}
