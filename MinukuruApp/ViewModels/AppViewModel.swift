import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    enum Screen {
        case home
        case modeSelect
        case quiz(QuizSessionViewModel)
        case result(QuizSessionViewModel, QuizEvaluation)
        case stats
    }

    @Published private(set) var screen: Screen = .home
    @Published private(set) var stats: UserStats
    @Published private(set) var results: [QuizResult]

    let repository: QuizProviding
    private let statsStore: StatsStoring
    private var modeProgress: [GameMode: Int] = [:]

    init(
        repository: QuizProviding = LocalQuizRepository(),
        statsStore: StatsStoring = UserDefaultsStatsStore()
    ) {
        self.repository = repository
        self.statsStore = statsStore
        self.stats = statsStore.loadStats()
        self.results = statsStore.loadResults()
    }

    var screenID: String {
        switch screen {
        case .home: "home"
        case .modeSelect: "modeSelect"
        case .quiz(let viewModel): "quiz-\(viewModel.question.id)"
        case .result(let viewModel, _): "result-\(viewModel.question.id)"
        case .stats: "stats"
        }
    }

    var badgeTitles: [String] {
        var badges: [String] = []
        if stats.totalChallenges >= 3 { badges.append("見抜き見習い") }
        if stats.correctAnswers >= 5 { badges.append("あやしい発見隊") }
        if stats.perfectAnswers >= 3 { badges.append("フェイクハンター") }
        if stats.bestStreak >= 5 { badges.append("コンコン名人") }
        if stats.totalScore >= 300 { badges.append("ミヌクルマスター") }
        return badges.isEmpty ? ["はじめの一歩"] : badges
    }

    var levelTitle: String {
        switch stats.totalScore {
        case 0..<60: "見抜き見習い"
        case 60..<140: "あやしい発見隊"
        case 140..<240: "フェイクハンター"
        case 240..<380: "コンコン名人"
        default: "ミヌクルマスター"
        }
    }

    var todayChallengeCount: Int {
        let calendar = Calendar.current
        return results.filter { calendar.isDateInToday($0.answeredAt) }.count
    }

    var totalQuestionCount: Int {
        repository.allQuestions().count
    }

    var accuracyText: String {
        guard stats.totalChallenges > 0 else { return "まだこれから" }
        let ratio = Double(stats.correctAnswers) / Double(stats.totalChallenges)
        return "\(Int((ratio * 100).rounded()))%"
    }

    var recentResults: [RecentResultSummary] {
        results
            .sorted { $0.answeredAt > $1.answeredAt }
            .prefix(5)
            .compactMap { result in
                guard let question = repository.question(id: result.questionId) else { return nil }
                return RecentResultSummary(
                    title: question.title,
                    modeTitle: question.mode.title,
                    score: result.score,
                    answeredAt: result.answeredAt,
                    wasPerfect: result.isPerfect
                )
            }
    }

    var modeProgressSummaries: [ModeProgressSummary] {
        GameMode.allCases.map { mode in
            let questions = repository.questions(for: mode)
            let modeResults = results.filter { repository.question(id: $0.questionId)?.mode == mode }
            return ModeProgressSummary(
                mode: mode,
                answeredCount: modeResults.count,
                totalCount: questions.count,
                perfectCount: modeResults.filter(\.isPerfect).count
            )
        }
    }

    func goHome() {
        screen = .home
    }

    func showModes() {
        screen = .modeSelect
    }

    func showStats() {
        screen = .stats
    }

    func startQuiz(for mode: GameMode) {
        let questions = repository.questions(for: mode)
        guard !questions.isEmpty else { return }
        let currentIndex = modeProgress[mode, default: 0] % questions.count
        let question = questions[currentIndex]
        let viewModel = QuizSessionViewModel(question: question, appViewModel: self)
        screen = .quiz(viewModel)
    }

    func showResult(for session: QuizSessionViewModel, evaluation: QuizEvaluation) {
        record(evaluation.result, matchedAnyCorrect: evaluation.matchedAnyCorrect)
        if let index = repository.questions(for: session.question.mode).firstIndex(of: session.question) {
            modeProgress[session.question.mode] = index + 1
        }
        screen = .result(session, evaluation)
    }

    func answeredCount(for mode: GameMode) -> Int {
        results.filter { repository.question(id: $0.questionId)?.mode == mode }.count
    }

    func resetStats() {
        results = []
        stats = UserStats()
        modeProgress = [:]
        statsStore.clearAll()
    }

    private func record(_ result: QuizResult, matchedAnyCorrect: Bool) {
        results.append(result)
        stats.totalChallenges += 1
        stats.totalScore += max(result.score, 5)

        if matchedAnyCorrect {
            stats.correctAnswers += 1
            stats.currentStreak += 1
            stats.bestStreak = max(stats.bestStreak, stats.currentStreak)
        } else {
            stats.currentStreak = 0
        }

        if result.isPerfect {
            stats.perfectAnswers += 1
        }

        statsStore.save(stats: stats)
        statsStore.save(results: results)
    }
}
