import Foundation

struct ModeProgressSummary: Identifiable {
    var id: GameMode { mode }
    let mode: GameMode
    let answeredCount: Int
    let totalCount: Int
    let perfectCount: Int

    var progressText: String {
        "\(answeredCount)/\(totalCount)問"
    }

    static func make(
        mode: GameMode,
        questions: [QuizQuestion],
        results: [QuizResult]
    ) -> ModeProgressSummary {
        let questionIDs = Set(questions.filter { $0.mode == mode }.map(\.id))
        let modeResults = results.filter { questionIDs.contains($0.questionId) }
        let answeredQuestionIDs = Set(modeResults.map(\.questionId))
        let correctQuestionIDs = Set(modeResults.filter(\.isPerfect).map(\.questionId))

        return ModeProgressSummary(
            mode: mode,
            answeredCount: answeredQuestionIDs.count,
            totalCount: questionIDs.count,
            perfectCount: correctQuestionIDs.count
        )
    }
}

struct RecentResultSummary: Identifiable {
    let id = UUID()
    let title: String
    let modeTitle: String
    let score: Int
    let answeredAt: Date
    let wasPerfect: Bool
}

struct ReasonTagSummary: Identifiable {
    var id: ReasonTag { tag }
    let tag: ReasonTag
    let selectedCount: Int
    let matchedCount: Int

    var accuracyRatio: Double {
        guard selectedCount > 0 else { return 0 }
        return Double(matchedCount) / Double(selectedCount)
    }

    var accuracyText: String {
        "\(Int((accuracyRatio * 100).rounded()))%"
    }
}
