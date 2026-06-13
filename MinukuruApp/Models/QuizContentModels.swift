import Foundation

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
    let minimumFetchIntervalMinutes: Int
    let freeQuestionLimit: Int

    static let fallback = RemoteQuizConfiguration(
        remoteQuestionsURL: nil,
        minimumFetchIntervalMinutes: 180,
        freeQuestionLimit: 50
    )

    enum CodingKeys: String, CodingKey {
        case remoteQuestionsURL
        case minimumFetchIntervalMinutes
        case freeQuestionLimit
    }

    init(
        remoteQuestionsURL: URL?,
        minimumFetchIntervalMinutes: Int,
        freeQuestionLimit: Int = 50
    ) {
        self.remoteQuestionsURL = remoteQuestionsURL
        self.minimumFetchIntervalMinutes = minimumFetchIntervalMinutes
        self.freeQuestionLimit = freeQuestionLimit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        remoteQuestionsURL = try container.decodeIfPresent(URL.self, forKey: .remoteQuestionsURL)
        minimumFetchIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .minimumFetchIntervalMinutes) ?? 180
        freeQuestionLimit = try container.decodeIfPresent(Int.self, forKey: .freeQuestionLimit) ?? 50
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
