import XCTest
@testable import Minukuru

final class HybridQuizRepositoryTests: XCTestCase {
    func testDecodeManifestSupportsBareQuestionArray() throws {
        let question = makeQuestion(id: "local-1", title: "ローカル")
        let data = try JSONEncoder().encode([question])

        let manifest = try FileQuizContentStore.decodeManifest(
            from: data,
            defaultVersion: "fallback-version"
        )

        XCTAssertEqual(manifest.contentVersion, "fallback-version")
        XCTAssertEqual(manifest.questions.map(\.id), ["local-1"])
    }

    func testRefreshReplacesQuestionsWhenRemoteManifestChanges() async throws {
        let bundledManifest = QuizContentManifest(
            contentVersion: "bundle-v1",
            questions: [makeQuestion(id: "bundle-1", title: "バンドル")]
        )
        let remoteManifest = QuizContentManifest(
            contentVersion: "remote-v2",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            questions: [makeQuestion(id: "remote-1", title: "リモート")]
        )
        let remoteData = try FileQuizContentStore.makeEncoder().encode(remoteManifest)

        let store = InMemoryQuizContentStore(
            bundledManifest: bundledManifest,
            configuration: RemoteQuizConfiguration(
                remoteQuestionsURL: URL(string: "https://example.com/questions.json"),
                minimumFetchIntervalMinutes: 0
            )
        )
        let repository = HybridQuizRepository(
            bundle: .main,
            store: store,
            remoteFetcher: MockQuizRemoteFetcher(result: .success(remoteData))
        )

        XCTAssertEqual(repository.allQuestions().map(\.id), ["bundle-1"])

        let didRefresh = await repository.refreshIfNeeded(force: false)

        XCTAssertTrue(didRefresh)
        XCTAssertEqual(repository.allQuestions().map(\.id), ["remote-1"])
        XCTAssertEqual(store.savedManifests[.full]?.contentVersion, "remote-v2")
    }

    func testSplitFeedRefreshMergesPremiumQuestionsAfterEntitlementUnlock() async throws {
        let bundledManifest = QuizContentManifest(
            contentVersion: "bundle-v1",
            questions: [makeQuestion(id: "free-1", title: "無料問題", accessTier: .free)]
        )
        let freeManifest = QuizContentManifest(
            contentVersion: "free-v2",
            questions: [makeQuestion(id: "free-2", title: "無料の追加", accessTier: .free)]
        )
        let premiumManifest = QuizContentManifest(
            contentVersion: "premium-v2",
            questions: [makeQuestion(id: "premium-1", title: "プレミアム", accessTier: .premium)]
        )

        let store = InMemoryQuizContentStore(
            bundledManifest: bundledManifest,
            configuration: RemoteQuizConfiguration(
                remoteQuestionsURL: URL(string: "https://example.com/full.json"),
                remoteFreeQuestionsURL: URL(string: "https://example.com/free.json"),
                remotePremiumQuestionsURL: URL(string: "https://example.com/premium.json"),
                minimumFetchIntervalMinutes: 0,
                minimumPremiumFetchIntervalMinutes: 0
            )
        )
        let fetcher = URLMapQuizRemoteFetcher(responses: [
            "https://example.com/free.json": try FileQuizContentStore.makeEncoder().encode(freeManifest),
            "https://example.com/premium.json": try FileQuizContentStore.makeEncoder().encode(premiumManifest),
        ])
        let repository = HybridQuizRepository(
            bundle: .main,
            store: store,
            remoteFetcher: fetcher
        )

        let freeOnlyRefresh = await repository.refreshIfNeeded(force: false)

        XCTAssertTrue(freeOnlyRefresh)
        XCTAssertEqual(repository.allQuestions().map(\.id), ["free-2"])

        repository.setPremiumAccess(true)
        let premiumRefresh = await repository.refreshIfNeeded(force: true)

        XCTAssertTrue(premiumRefresh)
        XCTAssertEqual(repository.allQuestions().map(\.id), ["free-2", "premium-1"])
        XCTAssertEqual(store.savedManifests[.free]?.contentVersion, "free-v2")
        XCTAssertEqual(store.savedManifests[.premium]?.contentVersion, "premium-v2")
    }

    private func makeQuestion(id: String, title: String, accessTier: AccessTier = .free) -> QuizQuestion {
        QuizQuestion(
            id: id,
            mode: .explanationSnipe,
            title: title,
            difficulty: .easy,
            instruction: "1こえらぼう",
            phoneticInstruction: nil,
            segments: [
                TextSegment(id: "s1", text: "本文です。", phoneticText: "ほんぶんです。")
            ],
            correctSegmentIds: ["s1"],
            explanation: "解説",
            phoneticExplanation: nil,
            verificationTip: "確認",
            phoneticVerificationTip: nil,
            hint: "ヒント",
            phoneticHint: nil,
            phoneticTitle: nil,
            recommendedReasonTags: [.gutFeeling],
            accessTier: accessTier,
            authorName: nil,
            authorId: nil,
            reviewStatus: nil,
            reportCount: nil,
            educationalScore: nil,
            safetyLevel: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }
}

private final class InMemoryQuizContentStore: QuizContentStoring {
    let bundledManifest: QuizContentManifest
    let configuration: RemoteQuizConfiguration
    var cachedManifests: [QuizContentCacheKind: QuizContentManifest] = [:]
    var savedManifests: [QuizContentCacheKind: QuizContentManifest] = [:]
    var lastFetchDates: [QuizContentCacheKind: Date] = [:]

    init(
        bundledManifest: QuizContentManifest,
        configuration: RemoteQuizConfiguration,
        cachedManifest: QuizContentManifest? = nil
    ) {
        self.bundledManifest = bundledManifest
        self.configuration = configuration
        if let cachedManifest {
            self.cachedManifests[.full] = cachedManifest
        }
    }

    func loadBundledManifest(from bundle: Bundle) -> QuizContentManifest {
        bundledManifest
    }

    func loadCachedManifest(kind: QuizContentCacheKind) -> QuizContentManifest? {
        cachedManifests[kind]
    }

    func saveCachedManifest(_ manifest: QuizContentManifest, kind: QuizContentCacheKind) {
        savedManifests[kind] = manifest
        cachedManifests[kind] = manifest
    }

    func loadConfiguration(from bundle: Bundle) -> RemoteQuizConfiguration {
        configuration
    }

    func shouldAttemptFetch(kind: QuizContentCacheKind, minimumIntervalMinutes: Int, now: Date, force: Bool) -> Bool {
        true
    }

    func markFetchAttempt(kind: QuizContentCacheKind, at date: Date) {
        lastFetchDates[kind] = date
    }
}

private struct MockQuizRemoteFetcher: QuizRemoteFetching {
    let result: Result<Data, Error>

    func fetchData(from url: URL) async throws -> Data {
        try result.get()
    }
}

private struct URLMapQuizRemoteFetcher: QuizRemoteFetching {
    let responses: [String: Data]

    func fetchData(from url: URL) async throws -> Data {
        guard let data = responses[url.absoluteString] else {
            throw URLError(.fileDoesNotExist)
        }
        return data
    }
}
