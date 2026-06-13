import Foundation

enum GameMode: String, Codable, CaseIterable, Identifiable {
    case explanationSnipe
    case newsPoison
    case scamAdChecker
    case profileHunter
    case conspiracyTrap

    var id: String { rawValue }

    var title: String {
        displayTitle(isHiraganaMode: false)
    }

    func displayTitle(isHiraganaMode: Bool) -> String {
        switch self {
        case .explanationSnipe:
            isHiraganaMode ? "せつめいぶんスナイプ" : "説明文スナイプ"
        case .newsPoison:
            isHiraganaMode ? "ニュースのどくばり" : "ニュースの毒針"
        case .scamAdChecker:
            isHiraganaMode ? "さぎこうこくチェッカー" : "詐欺広告チェッカー"
        case .profileHunter:
            isHiraganaMode ? "プロフィールぎそうハンター" : "プロフィール偽装ハンター"
        case .conspiracyTrap:
            isHiraganaMode ? "いんぼうろんトラップ" : "陰謀論トラップ"
        }
    }

    var shortDescription: String {
        displayShortDescription(isHiraganaMode: false)
    }

    func displayShortDescription(isHiraganaMode: Bool) -> String {
        switch self {
        case .explanationSnipe:
            isHiraganaMode ? "せつめいぶんに まぎれた まちがいを みつけよう" : "説明文にまぎれたまちがいを見つけよう"
        case .newsPoison:
            isHiraganaMode ? "ニュースふうの いいきりや すうじの ワナを みぬこう" : "ニュース風の言い切りや数字のワナを見抜こう"
        case .scamAdChecker:
            isHiraganaMode ? "こうこくの うますぎる はなしや いそがせる ことばに ちゅうい" : "広告のうますぎる話や急がせる言葉に注意"
        case .profileHunter:
            isHiraganaMode ? "すごそうに みせる プロフィールを おちついて かくにん" : "すごそうに見せるプロフィールを落ち着いて確認"
        case .conspiracyTrap:
            isHiraganaMode ? "ふあんを あおる ろんぽうや ひみつっぽい いいかたを まなぼう" : "不安をあおる論法や秘密っぽい言い方を学ぼう"
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
    let phoneticInstruction: String?
    let segments: [TextSegment]
    let correctSegmentIds: [String]
    let explanation: String
    let phoneticExplanation: String?
    let verificationTip: String
    let phoneticVerificationTip: String?
    let hint: String
    let phoneticHint: String?
    let phoneticTitle: String?
    let recommendedReasonTags: [ReasonTag]
    let accessTier: AccessTier
    let contentFlavor: ContentFlavor

    // Reserved for future online contribution features.
    let authorName: String?
    let authorId: String?
    let reviewStatus: String?
    let reportCount: Int?
    let educationalScore: Int?
    let safetyLevel: Int?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case mode
        case title
        case difficulty
        case instruction
        case phoneticInstruction
        case segments
        case correctSegmentIds
        case explanation
        case phoneticExplanation
        case verificationTip
        case phoneticVerificationTip
        case hint
        case phoneticHint
        case phoneticTitle
        case recommendedReasonTags
        case accessTier
        case contentFlavor
        case authorName
        case authorId
        case reviewStatus
        case reportCount
        case educationalScore
        case safetyLevel
        case createdAt
        case updatedAt
    }

    init(
        id: String,
        mode: GameMode,
        title: String,
        difficulty: Difficulty,
        instruction: String,
        phoneticInstruction: String? = nil,
        segments: [TextSegment],
        correctSegmentIds: [String],
        explanation: String,
        phoneticExplanation: String? = nil,
        verificationTip: String,
        phoneticVerificationTip: String? = nil,
        hint: String,
        phoneticHint: String? = nil,
        phoneticTitle: String? = nil,
        recommendedReasonTags: [ReasonTag],
        accessTier: AccessTier = .free,
        contentFlavor: ContentFlavor = .standard,
        authorName: String? = nil,
        authorId: String? = nil,
        reviewStatus: String? = nil,
        reportCount: Int? = nil,
        educationalScore: Int? = nil,
        safetyLevel: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.mode = mode
        self.title = title
        self.difficulty = difficulty
        self.instruction = instruction
        self.phoneticInstruction = phoneticInstruction
        self.segments = segments
        self.correctSegmentIds = correctSegmentIds
        self.explanation = explanation
        self.phoneticExplanation = phoneticExplanation
        self.verificationTip = verificationTip
        self.phoneticVerificationTip = phoneticVerificationTip
        self.hint = hint
        self.phoneticHint = phoneticHint
        self.phoneticTitle = phoneticTitle
        self.recommendedReasonTags = recommendedReasonTags
        self.accessTier = accessTier
        self.contentFlavor = contentFlavor
        self.authorName = authorName
        self.authorId = authorId
        self.reviewStatus = reviewStatus
        self.reportCount = reportCount
        self.educationalScore = educationalScore
        self.safetyLevel = safetyLevel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        mode = try container.decode(GameMode.self, forKey: .mode)
        title = try container.decode(String.self, forKey: .title)
        difficulty = try container.decode(Difficulty.self, forKey: .difficulty)
        instruction = try container.decode(String.self, forKey: .instruction)
        phoneticInstruction = try container.decodeIfPresent(String.self, forKey: .phoneticInstruction)
        segments = try container.decode([TextSegment].self, forKey: .segments)
        correctSegmentIds = try container.decode([String].self, forKey: .correctSegmentIds)
        explanation = try container.decode(String.self, forKey: .explanation)
        phoneticExplanation = try container.decodeIfPresent(String.self, forKey: .phoneticExplanation)
        verificationTip = try container.decode(String.self, forKey: .verificationTip)
        phoneticVerificationTip = try container.decodeIfPresent(String.self, forKey: .phoneticVerificationTip)
        hint = try container.decode(String.self, forKey: .hint)
        phoneticHint = try container.decodeIfPresent(String.self, forKey: .phoneticHint)
        phoneticTitle = try container.decodeIfPresent(String.self, forKey: .phoneticTitle)
        recommendedReasonTags = try container.decode([ReasonTag].self, forKey: .recommendedReasonTags)
        accessTier = try container.decodeIfPresent(AccessTier.self, forKey: .accessTier) ?? .free
        contentFlavor = try container.decodeIfPresent(ContentFlavor.self, forKey: .contentFlavor) ?? .standard
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName)
        authorId = try container.decodeIfPresent(String.self, forKey: .authorId)
        reviewStatus = try container.decodeIfPresent(String.self, forKey: .reviewStatus)
        reportCount = try container.decodeIfPresent(Int.self, forKey: .reportCount)
        educationalScore = try container.decodeIfPresent(Int.self, forKey: .educationalScore)
        safetyLevel = try container.decodeIfPresent(Int.self, forKey: .safetyLevel)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    func displayTitle(isHiraganaMode: Bool) -> String {
        if isHiraganaMode, let phoneticTitle {
            return phoneticTitle
        }
        return title
    }

    func displayInstruction(isHiraganaMode: Bool) -> String {
        if isHiraganaMode, let phoneticInstruction {
            return phoneticInstruction
        }
        return instruction
    }

    func displayExplanation(isHiraganaMode: Bool) -> String {
        if isHiraganaMode, let phoneticExplanation {
            return phoneticExplanation
        }
        return explanation
    }

    func displayVerificationTip(isHiraganaMode: Bool) -> String {
        if isHiraganaMode, let phoneticVerificationTip {
            return phoneticVerificationTip
        }
        return verificationTip
    }

    func displayHint(isHiraganaMode: Bool) -> String {
        if isHiraganaMode, let phoneticHint {
            return phoneticHint
        }
        return hint
    }
}

enum AccessTier: String, Codable, CaseIterable {
    case free
    case premium
}

enum ContentFlavor: String, Codable, CaseIterable {
    case standard
    case realWorld
}

struct TextSegment: Identifiable, Codable, Hashable {
    let id: String
    let text: String
    let phoneticText: String?

    func displayText(isHiraganaMode: Bool) -> String {
        if isHiraganaMode, let phoneticText {
            return phoneticText
        }
        return text
    }
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
        displayLabel(isHiraganaMode: false)
    }

    func displayLabel(isHiraganaMode: Bool) -> String {
        switch self {
        case .suspiciousNumber: isHiraganaMode ? "すうじが あやしい" : "数字があやしい"
        case .noSource: isHiraganaMode ? "しゅってんが ない" : "出典がない"
        case .tooStrongClaim: isHiraganaMode ? "いいきりすぎ" : "言い切りすぎ"
        case .fearMongering: isHiraganaMode ? "ふあんを あおっている" : "不安をあおっている"
        case .urgency: isHiraganaMode ? "いそがせている" : "急がせている"
        case .tooGoodToBeTrue: isHiraganaMode ? "うますぎる はなし" : "うますぎる話"
        case .fakeAuthority: isHiraganaMode ? "ゆうめいじんっぽく みせている" : "有名人っぽく見せている"
        case .secretInfo: isHiraganaMode ? "ひみつの じょうほうと いっている" : "ひみつの情報と言っている"
        case .enemyFraming: isHiraganaMode ? "はんたいいけんを ぜんぶ あくものに している" : "反対意見を全部悪者にしている"
        case .forcedConnection: isHiraganaMode ? "ぐうぜんを むりやり つなげている" : "偶然をむりやりつなげている"
        case .hardToVerify: isHiraganaMode ? "かくにんしにくい" : "確認しにくい"
        case .gutFeeling: isHiraganaMode ? "よく わからないけど あやしい" : "よくわからないけど怪しい"
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
