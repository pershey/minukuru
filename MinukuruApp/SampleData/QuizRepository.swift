import Foundation

protocol QuizProviding {
    func allQuestions() -> [QuizQuestion]
    func questions(for mode: GameMode) -> [QuizQuestion]
    func question(id: String) -> QuizQuestion?
}

protocol QuizRefreshing {
    func refreshIfNeeded(force: Bool) async -> Bool
}

protocol QuizAccessConfigProviding {
    var freeQuestionLimit: Int { get }
}

protocol QuizEntitlementAware {
    func setPremiumAccess(_ hasPremiumAccess: Bool)
    func setPremiumTransactionJWS(_ transactionJWS: String?)
}

extension QuizEntitlementAware {
    func setPremiumTransactionJWS(_ transactionJWS: String?) { }
}

struct QuizContentStatus: Equatable {
    let usesSplitFeeds: Bool
    let baseContentVersion: String
    let premiumContentVersion: String?
    let visibleQuestionCount: Int
    let premiumQuestionCount: Int
}

protocol QuizContentStatusProviding {
    func contentStatus() -> QuizContentStatus
}

protocol QuizRemoteFetching {
    func fetchData(from url: URL, premiumTransactionJWS: String?) async throws -> Data
}

struct URLSessionQuizRemoteFetcher: QuizRemoteFetching {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchData(from url: URL, premiumTransactionJWS: String?) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        if let premiumTransactionJWS, !premiumTransactionJWS.isEmpty {
            request.setValue(premiumTransactionJWS, forHTTPHeaderField: "X-Minukuru-StoreKit-JWS")
        }
        let (data, response) = try await session.data(for: request)

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

extension LocalQuizRepository: QuizContentStatusProviding {
    func contentStatus() -> QuizContentStatus {
        let premiumCount = questions.filter { $0.accessTier == .premium }.count
        return QuizContentStatus(
            usesSplitFeeds: false,
            baseContentVersion: "bundled-questions",
            premiumContentVersion: nil,
            visibleQuestionCount: questions.count,
            premiumQuestionCount: premiumCount
        )
    }
}

final class HybridQuizRepository: QuizProviding, QuizRefreshing, QuizAccessConfigProviding {
    private let bundle: Bundle
    private let store: QuizContentStoring
    private let remoteFetcher: QuizRemoteFetching
    private var baseManifest: QuizContentManifest
    private var premiumManifest: QuizContentManifest
    private let bundledCoreQuestions: [QuizQuestion]
    private var hasPremiumAccess = false
    private var premiumTransactionJWS: String?
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
        let coreQuestions = bundledManifest.questions.filter { $0.id.hasPrefix("core-") }
        self.bundledCoreQuestions = coreQuestions
        let configuration = store.loadConfiguration(from: bundle)
        self.freeQuestionLimit = configuration.freeQuestionLimit

        if configuration.usesSplitFeeds {
            let cachedBaseManifest =
                store.loadCachedManifest(kind: .free)
                ?? store.loadCachedManifest(kind: .full)
            let selectedBase = cachedBaseManifest?.questions.isEmpty == false ? cachedBaseManifest! : bundledManifest
            self.baseManifest = Self.withBundledCore(selectedBase, coreQuestions: coreQuestions)
            self.premiumManifest = store.loadCachedManifest(kind: .premium)
                ?? QuizContentManifest(contentVersion: "empty-premium", questions: [])
        } else {
            let cachedManifest = store.loadCachedManifest(kind: .full)
            let initialManifest = cachedManifest ?? bundledManifest
            let selectedBase = initialManifest.questions.isEmpty ? bundledManifest : initialManifest
            self.baseManifest = Self.withBundledCore(selectedBase, coreQuestions: coreQuestions)
            self.premiumManifest = QuizContentManifest(contentVersion: "empty-premium", questions: [])
        }
    }

    func allQuestions() -> [QuizQuestion] {
        currentManifest().questions
    }

    func questions(for mode: GameMode) -> [QuizQuestion] {
        currentManifest().questions.filter { $0.mode == mode }
    }

    func question(id: String) -> QuizQuestion? {
        currentManifest().questions.first { $0.id == id }
    }

    func refreshIfNeeded(force: Bool = false) async -> Bool {
        let configuration = store.loadConfiguration(from: bundle)
        let fetchDate = Date()
        var didRefresh = false

        if configuration.usesSplitFeeds {
            if let freeURL = configuration.effectiveFreeQuestionsURL,
               store.shouldAttemptFetch(
                   kind: .free,
                   minimumIntervalMinutes: configuration.minimumFetchIntervalMinutes,
                   now: fetchDate,
                   force: force
               ) {
                store.markFetchAttempt(kind: .free, at: fetchDate)
                didRefresh = await refreshManifest(
                    from: freeURL,
                    cacheKind: .free,
                    currentManifest: baseManifest,
                    premiumTransactionJWS: nil,
                    assign: { [weak self] refreshedManifest in
                        self?.baseManifest = refreshedManifest
                    }
                ) || didRefresh
            }

            if hasPremiumAccess,
               let premiumURL = configuration.remotePremiumQuestionsURL,
               store.shouldAttemptFetch(
                   kind: .premium,
                   minimumIntervalMinutes: configuration.minimumPremiumFetchIntervalMinutes,
                   now: fetchDate,
                   force: force
               ) {
                store.markFetchAttempt(kind: .premium, at: fetchDate)
                didRefresh = await refreshManifest(
                    from: premiumURL,
                    cacheKind: .premium,
                    currentManifest: premiumManifest,
                    premiumTransactionJWS: premiumTransactionJWS,
                    assign: { [weak self] refreshedManifest in
                        self?.premiumManifest = refreshedManifest
                    }
                ) || didRefresh
            }

            return didRefresh
        }

        guard let remoteURL = configuration.remoteQuestionsURL else { return false }
        guard store.shouldAttemptFetch(
            kind: .full,
            minimumIntervalMinutes: configuration.minimumFetchIntervalMinutes,
            now: fetchDate,
            force: force
        ) else {
            return false
        }

        store.markFetchAttempt(kind: .full, at: fetchDate)
        return await refreshManifest(
            from: remoteURL,
            cacheKind: .full,
            currentManifest: baseManifest,
            premiumTransactionJWS: hasPremiumAccess ? premiumTransactionJWS : nil,
            assign: { [weak self] refreshedManifest in
                self?.baseManifest = refreshedManifest
            }
        )
    }

    private func currentManifest() -> QuizContentManifest {
        guard hasPremiumAccess, !premiumManifest.questions.isEmpty else {
            return baseManifest
        }

        return QuizContentManifest(
            contentVersion: "\(baseManifest.contentVersion)+\(premiumManifest.contentVersion)",
            updatedAt: premiumManifest.updatedAt ?? baseManifest.updatedAt,
            questions: Self.mergeQuestions(baseManifest.questions, premiumManifest.questions)
        )
    }

    private static func mergeQuestions(_ baseQuestions: [QuizQuestion], _ overlayQuestions: [QuizQuestion]) -> [QuizQuestion] {
        var merged = baseQuestions
        var indexByID = Dictionary(uniqueKeysWithValues: merged.enumerated().map { ($1.id, $0) })

        for question in overlayQuestions {
            if let index = indexByID[question.id] {
                merged[index] = question
            } else {
                indexByID[question.id] = merged.count
                merged.append(question)
            }
        }

        return merged
    }

    private static func withBundledCore(
        _ manifest: QuizContentManifest,
        coreQuestions: [QuizQuestion]
    ) -> QuizContentManifest {
        guard !coreQuestions.isEmpty else { return manifest }
        return QuizContentManifest(
            schemaVersion: manifest.schemaVersion,
            contentVersion: manifest.contentVersion,
            updatedAt: manifest.updatedAt,
            questions: mergeQuestions(coreQuestions, manifest.questions)
        )
    }

    private func refreshManifest(
        from remoteURL: URL,
        cacheKind: QuizContentCacheKind,
        currentManifest: QuizContentManifest,
        premiumTransactionJWS: String?,
        assign: @escaping (QuizContentManifest) -> Void
    ) async -> Bool {
        do {
            let data = try await remoteFetcher.fetchData(
                from: remoteURL,
                premiumTransactionJWS: premiumTransactionJWS
            )
            let decodedManifest = try FileQuizContentStore.decodeManifest(
                from: data,
                defaultVersion: remoteURL.absoluteString
            )
            let refreshedManifest = cacheKind == .premium
                ? decodedManifest
                : Self.withBundledCore(decodedManifest, coreQuestions: bundledCoreQuestions)

            guard !refreshedManifest.questions.isEmpty else {
                return false
            }

            guard refreshedManifest != currentManifest else {
                return false
            }

            assign(refreshedManifest)
            store.saveCachedManifest(refreshedManifest, kind: cacheKind)
            return true
        } catch {
            return false
        }
    }
}

extension HybridQuizRepository: QuizEntitlementAware {
    func setPremiumAccess(_ hasPremiumAccess: Bool) {
        self.hasPremiumAccess = hasPremiumAccess
        if !hasPremiumAccess {
            premiumTransactionJWS = nil
        }
    }

    func setPremiumTransactionJWS(_ transactionJWS: String?) {
        premiumTransactionJWS = transactionJWS
    }
}

extension HybridQuizRepository: QuizContentStatusProviding {
    func contentStatus() -> QuizContentStatus {
        let mergedQuestions = currentManifest().questions
        return QuizContentStatus(
            usesSplitFeeds: store.loadConfiguration(from: bundle).usesSplitFeeds,
            baseContentVersion: baseManifest.contentVersion,
            premiumContentVersion: premiumManifest.questions.isEmpty ? nil : premiumManifest.contentVersion,
            visibleQuestionCount: mergedQuestions.count,
            premiumQuestionCount: mergedQuestions.filter { $0.accessTier == .premium }.count
        )
    }
}
