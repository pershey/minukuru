import Foundation

struct QuestionAccessPolicy {
    let freeQuestionLimit: Int

    init(freeQuestionLimit: Int = 50) {
        self.freeQuestionLimit = max(freeQuestionLimit, 1)
    }

    func visibleQuestions(
        from allQuestions: [QuizQuestion],
        settings: AppSettings,
        hasPremiumAccess: Bool
    ) -> [QuizQuestion] {
        let baseQuestions = allQuestions.filter { question in
            if !hasPremiumAccess && question.accessTier == .premium {
                return false
            }
            if question.contentFlavor == .realWorld && !hasPremiumAccess {
                return false
            }
            if question.contentFlavor == .realWorld && !settings.isRealityModeEnabled {
                return false
            }
            return true
        }

        if hasPremiumAccess {
            return baseQuestions
        }

        return Array(baseQuestions.prefix(freeQuestionLimit))
    }

    func nextQuestion(
        from questions: [QuizQuestion],
        progressIndex: Int,
        answeredQuestionIDs: Set<String>,
        skipAnswered: Bool
    ) -> QuizQuestion? {
        guard !questions.isEmpty else { return nil }

        if skipAnswered {
            let unanswered = questions.filter { !answeredQuestionIDs.contains($0.id) }
            if let nextUnanswered = unanswered.first {
                return nextUnanswered
            }
        }

        let safeIndex = progressIndex % questions.count
        return questions[safeIndex]
    }

    func premiumLockedQuestionCount(
        for mode: GameMode,
        allQuestions: [QuizQuestion],
        settings: AppSettings,
        hasPremiumAccess: Bool
    ) -> Int {
        let freeSettings = AppSettings(
            isHiraganaMode: settings.isHiraganaMode,
            isSkipAnsweredEnabled: false,
            isRealityModeEnabled: false
        )

        let premiumSettings = AppSettings(
            isHiraganaMode: settings.isHiraganaMode,
            isSkipAnsweredEnabled: settings.isSkipAnsweredEnabled,
            isRealityModeEnabled: settings.isRealityModeEnabled
        )

        let freeQuestions = visibleQuestions(from: allQuestions, settings: freeSettings, hasPremiumAccess: false)
            .filter { $0.mode == mode }
        let premiumQuestions = visibleQuestions(from: allQuestions, settings: premiumSettings, hasPremiumAccess: hasPremiumAccess)
            .filter { $0.mode == mode }

        return max(premiumQuestions.count - freeQuestions.count, 0)
    }
}
