import Foundation

enum QuizSessionPhase: String, Codable {
    case answer
    case reason
}

struct QuizSessionSnapshot: Codable, Equatable {
    let questionID: String
    let phase: QuizSessionPhase
    let selectedSegmentIDs: [String]
    let selectedReasonTags: [ReasonTag]
    let selectedChoiceID: String?
    let hintUsed: Bool
    let attemptNumber: Int
    let updatedAt: Date
}

protocol QuizSessionStoring {
    func loadSnapshot() -> QuizSessionSnapshot?
    func save(snapshot: QuizSessionSnapshot)
    func clearSnapshot()
}

final class UserDefaultsQuizSessionStore: QuizSessionStoring {
    private let defaults: UserDefaults
    private let key = "minukuru.quizSession"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSnapshot() -> QuizSessionSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(QuizSessionSnapshot.self, from: data)
    }

    func save(snapshot: QuizSessionSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    func clearSnapshot() {
        defaults.removeObject(forKey: key)
    }
}
