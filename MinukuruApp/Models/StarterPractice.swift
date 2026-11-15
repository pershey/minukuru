import Foundation

enum StarterPractice {
    static let questionIDs = [
        "core-ad-start-conditions",
        "core-ad-start-missing-info",
        "core-ad-start-mismatch"
    ]

    static func next(in questions: [QuizQuestion], results: [QuizResult]) -> QuizQuestion? {
        let completed = Set(results.map(\.questionId))
        for id in questionIDs where !completed.contains(id) {
            if let question = questions.first(where: { $0.id == id }) {
                return question
            }
        }
        return nil
    }

    static func endsAdEligibleSet(for result: QuizResult, history: [QuizResult]) -> Bool {
        let starterIDs = Set(questionIDs)
        guard !starterIDs.contains(result.questionId), history.last == result else { return false }
        var completedStarters: Set<String> = []
        var practiceIDs: Set<String> = []
        for item in history {
            if starterIDs.contains(item.questionId) {
                completedStarters.insert(item.questionId)
            } else if completedStarters == starterIDs, item.learningStage != .example, item.attemptNumber == 1 {
                let inserted = practiceIDs.insert(item.questionId).inserted
                if item == result {
                    return inserted && practiceIDs.count.isMultiple(of: 3)
                }
            }
        }
        return false
    }
}
