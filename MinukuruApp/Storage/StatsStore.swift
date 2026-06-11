import Foundation

protocol StatsStoring {
    func loadStats() -> UserStats
    func loadResults() -> [QuizResult]
    func save(stats: UserStats)
    func save(results: [QuizResult])
    func clearAll()
}

final class UserDefaultsStatsStore: StatsStoring {
    private let defaults: UserDefaults
    private let statsKey = "minukuru.userStats"
    private let resultsKey = "minukuru.quizResults"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadStats() -> UserStats {
        guard let data = defaults.data(forKey: statsKey),
              let stats = try? decoder.decode(UserStats.self, from: data) else {
            return UserStats()
        }
        return stats
    }

    func loadResults() -> [QuizResult] {
        guard let data = defaults.data(forKey: resultsKey),
              let results = try? decoder.decode([QuizResult].self, from: data) else {
            return []
        }
        return results
    }

    func save(stats: UserStats) {
        if let data = try? encoder.encode(stats) {
            defaults.set(data, forKey: statsKey)
        }
    }

    func save(results: [QuizResult]) {
        if let data = try? encoder.encode(results) {
            defaults.set(data, forKey: resultsKey)
        }
    }

    func clearAll() {
        defaults.removeObject(forKey: statsKey)
        defaults.removeObject(forKey: resultsKey)
    }
}
