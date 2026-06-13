import Foundation

protocol QuizContentStoring {
    func loadBundledManifest(from bundle: Bundle) -> QuizContentManifest
    func loadCachedManifest() -> QuizContentManifest?
    func saveCachedManifest(_ manifest: QuizContentManifest)
    func loadConfiguration(from bundle: Bundle) -> RemoteQuizConfiguration
    func shouldAttemptFetch(minimumIntervalMinutes: Int, now: Date) -> Bool
    func markFetchAttempt(at date: Date)
}

final class FileQuizContentStore: QuizContentStoring {
    private let fileManager: FileManager
    private let defaults: UserDefaults
    private let cacheDirectoryName = "MinukuruContent"
    private let cacheFilename = "cached-questions.json"
    private let lastFetchKey = "minukuru.quizContent.lastFetchAt"

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

    func loadCachedManifest() -> QuizContentManifest? {
        guard let data = try? Data(contentsOf: cacheFileURL()) else {
            return nil
        }

        return try? Self.decodeManifest(from: data, defaultVersion: "cached-questions")
    }

    func saveCachedManifest(_ manifest: QuizContentManifest) {
        do {
            let directoryURL = try cacheDirectoryURL()
            if !fileManager.fileExists(atPath: directoryURL.path) {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }

            let data = try Self.makeEncoder().encode(manifest)
            try data.write(to: cacheFileURL(), options: .atomic)
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

    func shouldAttemptFetch(minimumIntervalMinutes: Int, now: Date = Date()) -> Bool {
        guard minimumIntervalMinutes > 0 else { return true }
        guard let lastFetchAt = defaults.object(forKey: lastFetchKey) as? Date else { return true }
        return now.timeIntervalSince(lastFetchAt) >= TimeInterval(minimumIntervalMinutes * 60)
    }

    func markFetchAttempt(at date: Date) {
        defaults.set(date, forKey: lastFetchKey)
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

    private func cacheFileURL() -> URL {
        let baseURL = (try? cacheDirectoryURL())
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return baseURL.appendingPathComponent(cacheFilename)
    }
}
