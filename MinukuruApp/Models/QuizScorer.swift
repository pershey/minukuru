import Foundation

struct QuizEvaluation: Identifiable {
    let id = UUID()
    let result: QuizResult
    let scoreMessage: String
    let encouragement: String
    let selectedSegments: [TextSegment]
    let correctSegments: [TextSegment]
    let missedSegments: [TextSegment]
    let wrongSegments: [TextSegment]
    let matchedAnyCorrect: Bool
}

enum QuizScorer {
    static func evaluate(
        question: QuizQuestion,
        selectedSegmentIds: Set<String>,
        selectedReasonTags: Set<ReasonTag>,
        answeredAt: Date = Date()
    ) -> QuizEvaluation {
        let correctSet = Set(question.correctSegmentIds)
        let correctSelections = selectedSegmentIds.intersection(correctSet)
        let wrongSelections = selectedSegmentIds.subtracting(correctSet)
        let matchedTags = selectedReasonTags.intersection(Set(question.recommendedReasonTags))
        let missedSegments = question.segments.filter { correctSet.contains($0.id) && !selectedSegmentIds.contains($0.id) }
        let wrongSegments = question.segments.filter { wrongSelections.contains($0.id) }

        var score = correctSelections.count * 30
        score -= wrongSelections.count * 10
        score += matchedTags.count * 6
        if !selectedReasonTags.isEmpty {
            score += 4
        }

        let isPerfect = selectedSegmentIds == correctSet && !correctSet.isEmpty
        score += isPerfect ? 25 : 5
        score = max(score, 5)

        let result = QuizResult(
            questionId: question.id,
            selectedSegmentIds: Array(selectedSegmentIds).sorted(),
            selectedReasonTags: Array(selectedReasonTags).sorted(by: { $0.rawValue < $1.rawValue }),
            score: score,
            isPerfect: isPerfect,
            answeredAt: answeredAt
        )

        let encouragement: String
        if isPerfect {
            encouragement = "コンコン大成功！ よく見抜けたね。"
        } else if !correctSelections.isEmpty {
            encouragement = "おしい！でも、あやしいと思えたのはいいことです。"
        } else {
            encouragement = "だいじょうぶ。だまされないための練習なので、まちがえても大丈夫です。"
        }

        let scoreMessage: String
        if isPerfect {
            scoreMessage = "完全正解ボーナス！"
        } else if !correctSelections.isEmpty {
            scoreMessage = "次は数字や出典にも注目してみよう。"
        } else {
            scoreMessage = "ここは少し見抜きにくいワナでした。"
        }

        return QuizEvaluation(
            result: result,
            scoreMessage: scoreMessage,
            encouragement: encouragement,
            selectedSegments: question.segments.filter { selectedSegmentIds.contains($0.id) },
            correctSegments: question.segments.filter { correctSet.contains($0.id) },
            missedSegments: missedSegments,
            wrongSegments: wrongSegments,
            matchedAnyCorrect: !correctSelections.isEmpty
        )
    }
}
