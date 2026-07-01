import Foundation

enum QuizContentCacheKind: Hashable {
    case full
    case free
    case premium

    var cacheFilename: String {
        switch self {
        case .full:
            "cached-questions.json"
        case .free:
            "cached-free-questions.json"
        case .premium:
            "cached-premium-questions.json"
        }
    }

    var lastFetchKey: String {
        switch self {
        case .full:
            "minukuru.quizContent.full.lastFetchAt"
        case .free:
            "minukuru.quizContent.free.lastFetchAt"
        case .premium:
            "minukuru.quizContent.premium.lastFetchAt"
        }
    }
}

protocol QuizContentStoring {
    func loadBundledManifest(from bundle: Bundle) -> QuizContentManifest
    func loadCachedManifest(kind: QuizContentCacheKind) -> QuizContentManifest?
    func saveCachedManifest(_ manifest: QuizContentManifest, kind: QuizContentCacheKind)
    func loadConfiguration(from bundle: Bundle) -> RemoteQuizConfiguration
    func shouldAttemptFetch(kind: QuizContentCacheKind, minimumIntervalMinutes: Int, now: Date, force: Bool) -> Bool
    func markFetchAttempt(kind: QuizContentCacheKind, at date: Date)
}

final class FileQuizContentStore: QuizContentStoring {
    private let fileManager: FileManager
    private let defaults: UserDefaults
    private let cacheDirectoryName = "MinukuruContent"

    init(
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard
    ) {
        self.fileManager = fileManager
        self.defaults = defaults
    }

    func loadBundledManifest(from bundle: Bundle) -> QuizContentManifest {
        guard let url = bundle.url(forResource: "questions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? Self.decodeManifest(from: data, defaultVersion: "bundled-questions") else {
            assertionFailure("Bundled questions.json could not be loaded.")
            return QuizContentManifest(contentVersion: "empty-bundle", questions: [])
        }

        return manifest
    }

    func loadCachedManifest(kind: QuizContentCacheKind) -> QuizContentManifest? {
        guard let data = try? Data(contentsOf: cacheFileURL(for: kind)) else {
            return nil
        }

        return try? Self.decodeManifest(from: data, defaultVersion: "cached-questions")
    }

    func saveCachedManifest(_ manifest: QuizContentManifest, kind: QuizContentCacheKind) {
        do {
            let directoryURL = try cacheDirectoryURL()
            if !fileManager.fileExists(atPath: directoryURL.path) {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }

            let data = try Self.makeEncoder().encode(manifest)
            try data.write(to: cacheFileURL(for: kind), options: .atomic)
        } catch {
            assertionFailure("Could not save cached question manifest: \(error)")
        }
    }

    func loadConfiguration(from bundle: Bundle) -> RemoteQuizConfiguration {
        guard let url = bundle.url(forResource: "content_config", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let configuration = try? Self.makeDecoder().decode(RemoteQuizConfiguration.self, from: data) else {
            return .fallback
        }

        return configuration
    }

    func shouldAttemptFetch(
        kind: QuizContentCacheKind,
        minimumIntervalMinutes: Int,
        now: Date = Date(),
        force: Bool = false
    ) -> Bool {
        if force {
            return true
        }
        guard minimumIntervalMinutes > 0 else { return true }
        guard let lastFetchAt = defaults.object(forKey: kind.lastFetchKey) as? Date else { return true }
        return now.timeIntervalSince(lastFetchAt) >= TimeInterval(minimumIntervalMinutes * 60)
    }

    func markFetchAttempt(kind: QuizContentCacheKind, at date: Date) {
        defaults.set(date, forKey: kind.lastFetchKey)
    }

    static func decodeManifest(from data: Data, defaultVersion: String) throws -> QuizContentManifest {
        let payload = try makeDecoder().decode(QuizContentPayload.self, from: data)

        switch payload {
        case .manifest(let manifest):
            return manifest
        case .bareQuestions(let questions):
            return QuizContentManifest(contentVersion: defaultVersion, questions: questions)
        }
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func cacheDirectoryURL() throws -> URL {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return applicationSupport.appendingPathComponent(cacheDirectoryName, isDirectory: true)
    }

    private func cacheFileURL(for kind: QuizContentCacheKind) -> URL {
        let baseURL = (try? cacheDirectoryURL())
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return baseURL.appendingPathComponent(kind.cacheFilename)
    }
}
