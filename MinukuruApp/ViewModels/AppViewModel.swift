import Foundation
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    enum Screen {
        case home
        case modeSelect
        case quiz(QuizSessionViewModel)
        case result(QuizSessionViewModel, QuizEvaluation)
        case stats
        case settings
    }

    @Published private(set) var screen: Screen = .home
    @Published private(set) var stats: UserStats
    @Published private(set) var results: [QuizResult]
    @Published private(set) var questionBank: [QuizQuestion]
    @Published private(set) var isRefreshingContent = false
    @Published private(set) var contentRefreshMessage: String?
    @Published var settings: AppSettings

    let repository: QuizProviding
    let purchaseManager: PurchaseManager
    private let statsStore: StatsStoring
    private let settingsStore: AppSettingsStoring
    private let accessPolicy: QuestionAccessPolicy
    private var modeProgress: [GameMode: Int] = [:]
    private var practiceProgress: Int = 0
    private var hasAttemptedContentRefresh = false
    private var cancellables: Set<AnyCancellable> = []

    init(
        repository: QuizProviding = HybridQuizRepository(),
        purchaseManager: PurchaseManager,
        statsStore: StatsStoring = UserDefaultsStatsStore(),
        settingsStore: AppSettingsStoring = UserDefaultsAppSettingsStore()
    ) {
        self.repository = repository
        self.purchaseManager = purchaseManager
        self.statsStore = statsStore
        self.settingsStore = settingsStore
        self.accessPolicy = QuestionAccessPolicy(
            freeQuestionLimit: (repository as? QuizAccessConfigProviding)?.freeQuestionLimit ?? 50
        )
        (repository as? QuizEntitlementAware)?.setPremiumAccess(purchaseManager.hasPremiumAccess)
        self.stats = statsStore.loadStats()
        self.results = statsStore.loadResults()
        self.questionBank = repository.allQuestions()
        self.settings = settingsStore.loadSettings()

        purchaseManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        purchaseManager.$hasPremiumAccess
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] hasPremiumAccess in
                guard let self else { return }
                Task { @MainActor in
                    await self.handlePremiumAccessChanged(hasPremiumAccess)
                }
            }
            .store(in: &cancellables)
    }

    var screenID: String {
        switch screen {
        case .home: "home"
        case .modeSelect: "modeSelect"
        case .quiz(let viewModel): "quiz-\(viewModel.question.id)"
        case .result(let viewModel, _): "result-\(viewModel.question.id)"
        case .stats: "stats"
        case .settings: "settings"
        }
    }

    var badgeTitles: [String] {
        var badges: [String] = []
        if stats.totalChallenges >= 3 { badges.append("見抜き見習い") }
        if stats.correctAnswers >= 5 { badges.append("あやしい発見隊") }
        if stats.perfectAnswers >= 3 { badges.append("フェイクハンター") }
        if stats.bestStreak >= 5 { badges.append("見抜き名人") }
        if stats.totalScore >= 300 { badges.append("ミヌクルマスター") }
        return badges.isEmpty ? ["はじめの一歩"] : badges
    }

    var levelTitle: String {
        switch stats.totalScore {
        case 0..<60: "見抜き見習い"
        case 60..<140: "あやしい発見隊"
        case 140..<240: "フェイクハンター"
        case 240..<380: "見抜き名人"
        default: "ミヌクルマスター"
        }
    }

    var todayChallengeCount: Int {
        let calendar = Calendar.current
        return results.filter { calendar.isDateInToday($0.answeredAt) }.count
    }

    var totalQuestionCount: Int {
        accessibleQuestionBank.count
    }

    var loadedQuestionCount: Int {
        questionBank.count
    }

    var loadedPremiumQuestionCount: Int {
        questionBank.filter { $0.accessTier == .premium }.count
    }

    var loadedRealWorldQuestionCount: Int {
        questionBank.filter { $0.contentFlavor == .realWorld }.count
    }

    var contentStatus: QuizContentStatus? {
        (repository as? QuizContentStatusProviding)?.contentStatus()
    }

    var hasPremiumAccess: Bool {
        purchaseManager.hasPremiumAccess
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
                guard let question = question(id: result.questionId) else { return nil }
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
            let questions = questions(for: mode)
            let modeResults = results.filter { question(id: $0.questionId)?.mode == mode }
            return ModeProgressSummary(
                mode: mode,
                answeredCount: modeResults.count,
                totalCount: questions.count,
                perfectCount: modeResults.filter(\.isPerfect).count
            )
        }
    }

    var reasonTagSummaries: [ReasonTagSummary] {
        ReasonTag.allCases.compactMap { tag in
            let selectedCount = results.filter { $0.selectedReasonTags.contains(tag) }.count
            guard selectedCount > 0 else { return nil }

            let matchedCount = results.filter { result in
                guard result.selectedReasonTags.contains(tag),
                      let question = question(id: result.questionId) else {
                    return false
                }
                return question.recommendedReasonTags.contains(tag)
            }.count

            return ReasonTagSummary(
                tag: tag,
                selectedCount: selectedCount,
                matchedCount: matchedCount
            )
        }
        .sorted {
            if $0.matchedCount == $1.matchedCount {
                return $0.selectedCount > $1.selectedCount
            }
            return $0.matchedCount > $1.matchedCount
        }
    }

    var strongestReasoningSummary: ReasonTagSummary? {
        reasonTagSummaries.first
    }

    var recommendedFocusSummary: ReasonTagSummary? {
        reasonTagSummaries
            .filter { $0.selectedCount >= 2 }
            .sorted {
                if $0.accuracyRatio == $1.accuracyRatio {
                    return $0.selectedCount > $1.selectedCount
                }
                return $0.accuracyRatio < $1.accuracyRatio
            }
            .first
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

    func showSettings() {
        screen = .settings
    }

    func updateHiraganaMode(_ isEnabled: Bool) {
        settings.isHiraganaMode = isEnabled
        settingsStore.save(settings: settings)
    }

    func updateSkipAnsweredMode(_ isEnabled: Bool) {
        guard hasPremiumAccess else { return }
        settings.isSkipAnsweredEnabled = isEnabled
        settingsStore.save(settings: settings)
    }

    func updateRealityMode(_ isEnabled: Bool) {
        guard hasPremiumAccess else { return }
        settings.isRealityModeEnabled = isEnabled
        settingsStore.save(settings: settings)
    }

    func startPractice() {
        let questions = accessibleQuestionBank
        let answeredIDs = Set(results.map(\.questionId))
        guard let question = accessPolicy.nextQuestion(
            from: questions,
            progressIndex: practiceProgress,
            answeredQuestionIDs: answeredIDs,
            skipAnswered: hasPremiumAccess && settings.isSkipAnsweredEnabled
        ) else {
            return
        }
        let viewModel = QuizSessionViewModel(question: question, appViewModel: self)
        screen = .quiz(viewModel)
    }

    func startQuiz(for mode: GameMode) {
        let questions = questions(for: mode)
        let answeredIDs = Set(results.map(\.questionId))
        guard let question = accessPolicy.nextQuestion(
            from: questions,
            progressIndex: modeProgress[mode, default: 0],
            answeredQuestionIDs: answeredIDs,
            skipAnswered: hasPremiumAccess && settings.isSkipAnsweredEnabled
        ) else {
            return
        }
        let viewModel = QuizSessionViewModel(question: question, appViewModel: self)
        screen = .quiz(viewModel)
    }

    func showResult(for session: QuizSessionViewModel, evaluation: QuizEvaluation) {
        record(evaluation.result, matchedAnyCorrect: evaluation.matchedAnyCorrect)
        if let index = questions(for: session.question.mode).firstIndex(of: session.question) {
            modeProgress[session.question.mode] = index + 1
        }
        if let index = accessibleQuestionBank.firstIndex(of: session.question) {
            practiceProgress = index + 1
        }
        screen = .result(session, evaluation)
    }

    func answeredCount(for mode: GameMode) -> Int {
        results.filter { question(id: $0.questionId)?.mode == mode }.count
    }

    func questions(for mode: GameMode) -> [QuizQuestion] {
        accessibleQuestionBank.filter { $0.mode == mode }
    }

    func premiumLockedQuestionCount(for mode: GameMode) -> Int {
        accessPolicy.premiumLockedQuestionCount(
            for: mode,
            allQuestions: questionBank,
            settings: settings,
            hasPremiumAccess: true
        )
    }

    func question(id: String) -> QuizQuestion? {
        questionBank.first { $0.id == id }
    }

    func refreshQuestionContentIfNeeded(force: Bool = false) async {
        isRefreshingContent = true
        defer { isRefreshingContent = false }

        if !force {
            guard !hasAttemptedContentRefresh else { return }
            hasAttemptedContentRefresh = true
        }

        (repository as? QuizEntitlementAware)?.setPremiumAccess(hasPremiumAccess)
        guard let refreshingRepository = repository as? QuizRefreshing else { return }
        let didRefresh = await refreshingRepository.refreshIfNeeded(force: force)
        guard didRefresh || force else { return }

        questionBank = repository.allQuestions()
    }

    func manuallyRefreshQuestionContent() async {
        await refreshQuestionContentIfNeeded(force: true)

        if hasPremiumAccess {
            contentRefreshMessage = "問題を更新しました。いまは \(accessibleQuestionBank.count)問遊べます。"
        } else {
            contentRefreshMessage = "問題を更新しました。いまは \(accessibleQuestionBank.count)問遊べます。"
        }
    }

    func resetStats() {
        results = []
        stats = UserStats()
        modeProgress = [:]
        practiceProgress = 0
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

    private var accessibleQuestionBank: [QuizQuestion] {
        accessPolicy.visibleQuestions(
            from: questionBank,
            settings: settings,
            hasPremiumAccess: hasPremiumAccess
        )
    }

    private func handlePremiumAccessChanged(_ hasPremiumAccess: Bool) async {
        (repository as? QuizEntitlementAware)?.setPremiumAccess(hasPremiumAccess)
        questionBank = repository.allQuestions()

        guard hasPremiumAccess else { return }
        await refreshQuestionContentIfNeeded(force: true)
        contentRefreshMessage = "プレミアム問題を読み込みました。いまは \(accessibleQuestionBank.count)問遊べます。"
    }
}
