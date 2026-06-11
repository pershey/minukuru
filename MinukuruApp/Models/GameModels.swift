import Foundation

enum GameMode: String, Codable, CaseIterable, Identifiable {
    case explanationSnipe
    case newsPoison
    case scamAdChecker
    case profileHunter
    case conspiracyTrap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explanationSnipe:
            "説明文スナイプ"
        case .newsPoison:
            "ニュースの毒針"
        case .scamAdChecker:
            "詐欺広告チェッカー"
        case .profileHunter:
            "プロフィール偽装ハンター"
        case .conspiracyTrap:
            "陰謀論トラップ"
        }
    }

    var shortDescription: String {
        switch self {
        case .explanationSnipe:
            "説明文にまぎれたまちがいを見つけよう"
        case .newsPoison:
            "ニュース風の言い切りや数字のワナを見抜こう"
        case .scamAdChecker:
            "広告のうますぎる話や急がせる言葉に注意"
        case .profileHunter:
            "すごそうに見せるプロフィールを落ち着いて確認"
        case .conspiracyTrap:
            "不安をあおる論法や秘密っぽい言い方を学ぼう"
        }
    }

    var icon: String {
        switch self {
        case .explanationSnipe:
            "text.magnifyingglass"
        case .newsPoison:
            "newspaper.fill"
        case .scamAdChecker:
            "exclamationmark.bubble.fill"
        case .profileHunter:
            "person.crop.rectangle.stack.fill"
        case .conspiracyTrap:
            "eye.trianglebadge.exclamationmark.fill"
        }
    }
}

struct QuizQuestion: Identifiable, Codable, Hashable {
    let id: String
    let mode: GameMode
    let title: String
    let difficulty: Difficulty
    let instruction: String
    let segments: [TextSegment]
    let correctSegmentIds: [String]
    let explanation: String
    let verificationTip: String
    let hint: String
    let recommendedReasonTags: [ReasonTag]

    // Reserved for future online contribution features.
    let authorName: String?
    let authorId: String?
    let reviewStatus: String?
    let reportCount: Int?
    let educationalScore: Int?
    let safetyLevel: Int?
    let createdAt: Date?
    let updatedAt: Date?
}

struct TextSegment: Identifiable, Codable, Hashable {
    let id: String
    let text: String
}

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy
    case normal
    case hard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .easy: "やさしい"
        case .normal: "ふつう"
        case .hard: "むずかしい"
        }
    }
}

enum ReasonTag: String, Codable, CaseIterable, Identifiable {
    case suspiciousNumber
    case noSource
    case tooStrongClaim
    case fearMongering
    case urgency
    case tooGoodToBeTrue
    case fakeAuthority
    case secretInfo
    case enemyFraming
    case forcedConnection
    case hardToVerify
    case gutFeeling

    var id: String { rawValue }

    var label: String {
        switch self {
        case .suspiciousNumber: "数字があやしい"
        case .noSource: "出典がない"
        case .tooStrongClaim: "言い切りすぎ"
        case .fearMongering: "不安をあおっている"
        case .urgency: "急がせている"
        case .tooGoodToBeTrue: "うますぎる話"
        case .fakeAuthority: "有名人っぽく見せている"
        case .secretInfo: "ひみつの情報と言っている"
        case .enemyFraming: "反対意見を全部悪者にしている"
        case .forcedConnection: "偶然をむりやりつなげている"
        case .hardToVerify: "確認しにくい"
        case .gutFeeling: "よくわからないけど怪しい"
        }
    }
}

struct QuizResult: Codable, Hashable {
    let questionId: String
    let selectedSegmentIds: [String]
    let selectedReasonTags: [ReasonTag]
    let score: Int
    let isPerfect: Bool
    let answeredAt: Date
}

struct UserStats: Codable, Hashable {
    var totalChallenges: Int = 0
    var correctAnswers: Int = 0
    var perfectAnswers: Int = 0
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var totalScore: Int = 0
}

struct ModeCard: Identifiable {
    let id = UUID()
    let mode: GameMode
    let difficulty: Difficulty
}
