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
    let matchedReasonTags: [ReasonTag]
    let missedRecommendedTags: [ReasonTag]
    let offTargetReasonTags: [ReasonTag]
    let reasoningMessage: String
}

enum QuizScorer {
    static func evaluate(
        question: QuizQuestion,
        selectedSegmentIds: Set<String>,
        selectedReasonTags: Set<ReasonTag>,
        answeredAt: Date = Date()
    ) -> QuizEvaluation {
        let correctSet = Set(question.correctSegmentIds)
        let recommendedSet = Set(question.recommendedReasonTags)
        let correctSelections = selectedSegmentIds.intersection(correctSet)
        let wrongSelections = selectedSegmentIds.subtracting(correctSet)
        let matchedTags = selectedReasonTags.intersection(recommendedSet)
        let missedRecommendedTags = recommendedSet.subtracting(selectedReasonTags)
        let offTargetReasonTags = selectedReasonTags.subtracting(recommendedSet)
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
            encouragement = "すばらしい！ よく見抜けたね。"
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

        let reasoningMessage: String
        if selectedReasonTags.isEmpty {
            reasoningMessage = "今回は理由タグなしでした。次は『どこが気になったか』も言葉にしてみよう。"
        } else if !matchedTags.isEmpty && offTargetReasonTags.isEmpty {
            reasoningMessage = "見方がかなり合っています。どこを怪しいと思ったか、うまく言葉にできています。"
        } else if !matchedTags.isEmpty {
            reasoningMessage = "見方は合っています。今回は別の見方も少し混ざっていたので、比べながら覚えていこう。"
        } else {
            reasoningMessage = "タグの見方は少しずれました。でも、違和感を持てたこと自体が大切な一歩です。"
        }

        return QuizEvaluation(
            result: result,
            scoreMessage: scoreMessage,
            encouragement: encouragement,
            selectedSegments: question.segments.filter { selectedSegmentIds.contains($0.id) },
            correctSegments: question.segments.filter { correctSet.contains($0.id) },
            missedSegments: missedSegments,
            wrongSegments: wrongSegments,
            matchedAnyCorrect: !correctSelections.isEmpty,
            matchedReasonTags: matchedTags.sorted(by: { $0.rawValue < $1.rawValue }),
            missedRecommendedTags: missedRecommendedTags.sorted(by: { $0.rawValue < $1.rawValue }),
            offTargetReasonTags: offTargetReasonTags.sorted(by: { $0.rawValue < $1.rawValue }),
            reasoningMessage: reasoningMessage
        )
    }
}
