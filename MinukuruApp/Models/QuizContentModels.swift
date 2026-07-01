import Foundation

enum RemoteManifestChannel: String, Codable, CaseIterable {
    case full
    case free
    case premium
}

struct QuizContentManifest: Codable, Equatable {
    let schemaVersion: Int
    let contentVersion: String
    let updatedAt: Date?
    let questions: [QuizQuestion]

    init(
        schemaVersion: Int = 1,
        contentVersion: String,
        updatedAt: Date? = nil,
        questions: [QuizQuestion]
    ) {
        self.schemaVersion = schemaVersion
        self.contentVersion = contentVersion
        self.updatedAt = updatedAt
        self.questions = questions
    }
}

struct RemoteQuizConfiguration: Codable, Equatable {
    let remoteQuestionsURL: URL?
    let remoteFreeQuestionsURL: URL?
    let remotePremiumQuestionsURL: URL?
    let minimumFetchIntervalMinutes: Int
    let minimumPremiumFetchIntervalMinutes: Int
    let freeQuestionLimit: Int

    static let fallback = RemoteQuizConfiguration(
        remoteQuestionsURL: nil,
        remoteFreeQuestionsURL: nil,
        remotePremiumQuestionsURL: nil,
        minimumFetchIntervalMinutes: 180,
        minimumPremiumFetchIntervalMinutes: 15,
        freeQuestionLimit: 50
    )

    enum CodingKeys: String, CodingKey {
        case remoteQuestionsURL
        case remoteFreeQuestionsURL
        case remotePremiumQuestionsURL
        case minimumFetchIntervalMinutes
        case minimumPremiumFetchIntervalMinutes
        case freeQuestionLimit
    }

    init(
        remoteQuestionsURL: URL?,
        remoteFreeQuestionsURL: URL? = nil,
        remotePremiumQuestionsURL: URL? = nil,
        minimumFetchIntervalMinutes: Int,
        minimumPremiumFetchIntervalMinutes: Int = 15,
        freeQuestionLimit: Int = 50
    ) {
        self.remoteQuestionsURL = remoteQuestionsURL
        self.remoteFreeQuestionsURL = remoteFreeQuestionsURL
        self.remotePremiumQuestionsURL = remotePremiumQuestionsURL
        self.minimumFetchIntervalMinutes = minimumFetchIntervalMinutes
        self.minimumPremiumFetchIntervalMinutes = minimumPremiumFetchIntervalMinutes
        self.freeQuestionLimit = freeQuestionLimit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        remoteQuestionsURL = try container.decodeIfPresent(URL.self, forKey: .remoteQuestionsURL)
        remoteFreeQuestionsURL = try container.decodeIfPresent(URL.self, forKey: .remoteFreeQuestionsURL)
        remotePremiumQuestionsURL = try container.decodeIfPresent(URL.self, forKey: .remotePremiumQuestionsURL)
        minimumFetchIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .minimumFetchIntervalMinutes) ?? 180
        minimumPremiumFetchIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .minimumPremiumFetchIntervalMinutes) ?? 15
        freeQuestionLimit = try container.decodeIfPresent(Int.self, forKey: .freeQuestionLimit) ?? 50
    }

    var usesSplitFeeds: Bool {
        remoteFreeQuestionsURL != nil || remotePremiumQuestionsURL != nil
    }

    var effectiveFreeQuestionsURL: URL? {
        if let remoteFreeQuestionsURL {
            return remoteFreeQuestionsURL
        }
        return remoteQuestionsURL
    }
}

enum QuizContentPayload: Decodable {
    case manifest(QuizContentManifest)
    case bareQuestions([QuizQuestion])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let manifest = try? container.decode(QuizContentManifest.self) {
            self = .manifest(manifest)
            return
        }

        self = .bareQuestions(try container.decode([QuizQuestion].self))
    }
}
