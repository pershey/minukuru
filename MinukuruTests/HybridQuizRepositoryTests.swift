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

        let didRefresh = await repository.refreshIfNeeded()

        XCTAssertTrue(didRefresh)
        XCTAssertEqual(repository.allQuestions().map(\.id), ["remote-1"])
        XCTAssertEqual(store.savedManifest?.contentVersion, "remote-v2")
    }

    private func makeQuestion(id: String, title: String) -> QuizQuestion {
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
    var cachedManifest: QuizContentManifest?
    var savedManifest: QuizContentManifest?
    var lastFetchAt: Date?

    init(
        bundledManifest: QuizContentManifest,
        configuration: RemoteQuizConfiguration,
        cachedManifest: QuizContentManifest? = nil
    ) {
        self.bundledManifest = bundledManifest
        self.configuration = configuration
        self.cachedManifest = cachedManifest
    }

    func loadBundledManifest(from bundle: Bundle) -> QuizContentManifest {
        bundledManifest
    }

    func loadCachedManifest() -> QuizContentManifest? {
        cachedManifest
    }

    func saveCachedManifest(_ manifest: QuizContentManifest) {
        savedManifest = manifest
        cachedManifest = manifest
    }

    func loadConfiguration(from bundle: Bundle) -> RemoteQuizConfiguration {
        configuration
    }

    func shouldAttemptFetch(minimumIntervalMinutes: Int, now: Date) -> Bool {
        true
    }

    func markFetchAttempt(at date: Date) {
        lastFetchAt = date
    }
}

private struct MockQuizRemoteFetcher: QuizRemoteFetching {
    let result: Result<Data, Error>

    func fetchData(from url: URL) async throws -> Data {
        try result.get()
    }
}
