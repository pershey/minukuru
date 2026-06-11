import Foundation

protocol QuizProviding {
    func allQuestions() -> [QuizQuestion]
    func questions(for mode: GameMode) -> [QuizQuestion]
    func question(id: String) -> QuizQuestion?
}

struct LocalQuizRepository: QuizProviding {
    private let questions: [QuizQuestion]

    init(bundle: Bundle = .main) {
        self.questions = Self.loadQuestions(from: bundle)
    }

    func allQuestions() -> [QuizQuestion] {
        questions
    }

    func questions(for mode: GameMode) -> [QuizQuestion] {
        questions.filter { $0.mode == mode }
    }

    func question(id: String) -> QuizQuestion? {
        questions.first { $0.id == id }
    }

    private static func loadQuestions(from bundle: Bundle) -> [QuizQuestion] {
        guard let url = bundle.url(forResource: "questions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let questions = try? JSONDecoder().decode([QuizQuestion].self, from: data) else {
            assertionFailure("questions.json could not be loaded from the app bundle.")
            return []
        }

        return questions
    }
}
