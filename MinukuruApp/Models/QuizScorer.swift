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
    let selectedChoice: AnswerChoice?
    let correctChoice: AnswerChoice?
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
        selectedChoiceId: String? = nil,
        hintUsed: Bool = false,
        attemptNumber: Int = 1,
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

        let selectedChoice = question.answerChoices.first { $0.id == selectedChoiceId }
        let correctChoice = question.answerChoices.first { $0.id == question.correctChoiceId }
        let isPerfect: Bool
        var score: Int

        switch question.responseType {
        case .selectSegments:
            let answerIsCorrect = selectedSegmentIds == correctSet && !correctSet.isEmpty
            let reasonIsCorrect = recommendedSet.isEmpty || (!matchedTags.isEmpty && offTargetReasonTags.isEmpty)
            isPerfect = answerIsCorrect && reasonIsCorrect
            score = correctSelections.count * 30
            score -= wrongSelections.count * 10
            score += matchedTags.count * 6
            if !selectedReasonTags.isEmpty {
                score += 4
            }
            score += isPerfect ? 25 : 5
        case .singleChoice:
            isPerfect = selectedChoiceId != nil && selectedChoiceId == question.correctChoiceId
            score = isPerfect ? 65 : 5
        }

        if question.learningStage == .example {
            score = 5
        } else if hintUsed {
            score = max(score - 10, 5)
        }
        score = max(score, 5)

        let result = QuizResult(
            questionId: question.id,
            selectedSegmentIds: Array(selectedSegmentIds).sorted(),
            selectedReasonTags: Array(selectedReasonTags).sorted(by: { $0.rawValue < $1.rawValue }),
            selectedChoiceId: selectedChoiceId,
            responseType: question.responseType,
            score: score,
            isPerfect: isPerfect,
            hintUsed: hintUsed,
            attemptNumber: attemptNumber,
            learningStage: question.learningStage,
            contentRevision: question.contentRevision,
            answeredAt: answeredAt
        )

        let encouragement: String
        if question.learningStage == .example {
            encouragement = "お手本を確認しました。"
        } else if isPerfect {
            encouragement = "答えと考え方が合っています。"
        } else if !correctSelections.isEmpty {
            encouragement = "一部に気づけました。見逃した点も確認しましょう。"
        } else {
            encouragement = "今回は答えが違いました。理由を確かめれば大丈夫です。"
        }

        let scoreMessage: String
        if question.learningStage == .example {
            scoreMessage = question.learningFocus.prompt(isHiraganaMode: false)
        } else if isPerfect && hintUsed {
            scoreMessage = "ヒントを使って確認できました。次は別の文でも試してみましょう。"
        } else if isPerfect {
            scoreMessage = "自分で根拠を確かめられました。"
        } else if !correctSelections.isEmpty {
            scoreMessage = "どの言葉を根拠にしたか、解説と比べてみましょう。"
        } else {
            scoreMessage = "何でも疑うのではなく、判断できる材料を探してみましょう。"
        }

        let reasoningMessage: String
        if selectedReasonTags.isEmpty {
            reasoningMessage = "解説を読んで、どの見方が使えたか確認しましょう。"
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
            matchedAnyCorrect: question.responseType == .singleChoice ? isPerfect : !correctSelections.isEmpty,
            selectedChoice: selectedChoice,
            correctChoice: correctChoice,
            matchedReasonTags: matchedTags.sorted(by: { $0.rawValue < $1.rawValue }),
            missedRecommendedTags: missedRecommendedTags.sorted(by: { $0.rawValue < $1.rawValue }),
            offTargetReasonTags: offTargetReasonTags.sorted(by: { $0.rawValue < $1.rawValue }),
            reasoningMessage: reasoningMessage
        )
    }
}
