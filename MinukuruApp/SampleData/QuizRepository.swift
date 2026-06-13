import Foundation

protocol QuizProviding {
    func allQuestions() -> [QuizQuestion]
    func questions(for mode: GameMode) -> [QuizQuestion]
    func question(id: String) -> QuizQuestion?
}

protocol QuizRefreshing {
    func refreshIfNeeded() async -> Bool
}

protocol QuizAccessConfigProviding {
    var freeQuestionLimit: Int { get }
}

protocol QuizRemoteFetching {
    func fetchData(from url: URL) async throws -> Data
}

struct URLSessionQuizRemoteFetcher: QuizRemoteFetching {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        return data
    }
}

struct LocalQuizRepository: QuizProviding, QuizAccessConfigProviding {
    private let questions: [QuizQuestion]
    let freeQuestionLimit: Int

    init(bundle: Bundle = .main) {
        let configuration = FileQuizContentStore().loadConfiguration(from: bundle)
        self.questions = Self.loadQuestions(from: bundle)
        self.freeQuestionLimit = configuration.freeQuestionLimit
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
        FileQuizContentStore()
            .loadBundledManifest(from: bundle)
            .questions
    }
}

final class HybridQuizRepository: QuizProviding, QuizRefreshing, QuizAccessConfigProviding {
    private let bundle: Bundle
    private let store: QuizContentStoring
    private let remoteFetcher: QuizRemoteFetching
    private var manifest: QuizContentManifest
    let freeQuestionLimit: Int

    init(
        bundle: Bundle = .main,
        store: QuizContentStoring = FileQuizContentStore(),
        remoteFetcher: QuizRemoteFetching = URLSessionQuizRemoteFetcher()
    ) {
        self.bundle = bundle
        self.store = store
        self.remoteFetcher = remoteFetcher

        let bundledManifest = store.loadBundledManifest(from: bundle)
        let cachedManifest = store.loadCachedManifest()
        let initialManifest = cachedManifest ?? bundledManifest
        let configuration = store.loadConfiguration(from: bundle)
        self.manifest = initialManifest.questions.isEmpty ? bundledManifest : initialManifest
        self.freeQuestionLimit = configuration.freeQuestionLimit
    }

    func allQuestions() -> [QuizQuestion] {
        manifest.questions
    }

    func questions(for mode: GameMode) -> [QuizQuestion] {
        manifest.questions.filter { $0.mode == mode }
    }

    func question(id: String) -> QuizQuestion? {
        manifest.questions.first { $0.id == id }
    }

    func refreshIfNeeded() async -> Bool {
        let configuration = store.loadConfiguration(from: bundle)
        guard let remoteURL = configuration.remoteQuestionsURL else { return false }

        let fetchDate = Date()
        guard store.shouldAttemptFetch(
            minimumIntervalMinutes: configuration.minimumFetchIntervalMinutes,
            now: fetchDate
        ) else {
            return false
        }

        store.markFetchAttempt(at: fetchDate)

        do {
            let data = try await remoteFetcher.fetchData(from: remoteURL)
            let refreshedManifest = try FileQuizContentStore.decodeManifest(
                from: data,
                defaultVersion: remoteURL.absoluteString
            )

            guard !refreshedManifest.questions.isEmpty else {
                return false
            }

            guard refreshedManifest != manifest else {
                return false
            }

            manifest = refreshedManifest
            store.saveCachedManifest(refreshedManifest)
            return true
        } catch {
            return false
        }
    }
}
