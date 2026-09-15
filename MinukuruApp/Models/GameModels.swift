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
    let audience: LearnerAudience
    let learningStage: LearningStage
    let learningFocus: LearningFocus
    let responseType: QuestionResponseType
    let answerChoices: [AnswerChoice]
    let correctChoiceId: String?
    let attentionPoint: String?
    let phoneticAttentionPoint: String?
    let contentRevision: Int

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
        case audience
        case learningStage
        case learningFocus
        case responseType
        case answerChoices
        case correctChoiceId
        case attentionPoint
        case phoneticAttentionPoint
        case contentRevision
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
        audience: LearnerAudience = .general,
        learningStage: LearningStage = .challenge,
        learningFocus: LearningFocus = .evidence,
        responseType: QuestionResponseType = .selectSegments,
        answerChoices: [AnswerChoice] = [],
        correctChoiceId: String? = nil,
        attentionPoint: String? = nil,
        phoneticAttentionPoint: String? = nil,
        contentRevision: Int = 1,
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
        self.audience = audience
        self.learningStage = learningStage
        self.learningFocus = learningFocus
        self.responseType = responseType
        self.answerChoices = answerChoices
        self.correctChoiceId = correctChoiceId
        self.attentionPoint = attentionPoint
        self.phoneticAttentionPoint = phoneticAttentionPoint
        self.contentRevision = max(contentRevision, 1)
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
        audience = try container.decodeIfPresent(LearnerAudience.self, forKey: .audience) ?? .general
        learningStage = try container.decodeIfPresent(LearningStage.self, forKey: .learningStage) ?? .challenge
        learningFocus = try container.decodeIfPresent(LearningFocus.self, forKey: .learningFocus) ?? .evidence
        responseType = try container.decodeIfPresent(QuestionResponseType.self, forKey: .responseType) ?? .selectSegments
        answerChoices = try container.decodeIfPresent([AnswerChoice].self, forKey: .answerChoices) ?? []
        correctChoiceId = try container.decodeIfPresent(String.self, forKey: .correctChoiceId)
        attentionPoint = try container.decodeIfPresent(String.self, forKey: .attentionPoint)
        phoneticAttentionPoint = try container.decodeIfPresent(String.self, forKey: .phoneticAttentionPoint)
        contentRevision = max(try container.decodeIfPresent(Int.self, forKey: .contentRevision) ?? 1, 1)
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

    func displayAttentionPoint(isHiraganaMode: Bool) -> String {
        if isHiraganaMode, let phoneticAttentionPoint {
            return phoneticAttentionPoint
        }
        if let attentionPoint {
            return attentionPoint
        }
        if let firstCorrectSegment = segments.first(where: { correctSegmentIds.contains($0.id) }) {
            return "「\(firstCorrectSegment.displayText(isHiraganaMode: isHiraganaMode))」に注目します。"
        }
        return isHiraganaMode ? "ぶんしょうと えらんだ こたえを くらべます。" : "文章と選んだ答えを比べます。"
    }

    var fullText: String {
        segments.map(\.text).joined(separator: "")
    }

    func displayFullText(isHiraganaMode: Bool) -> String {
        segments.map { $0.displayText(isHiraganaMode: isHiraganaMode) }.joined(separator: "")
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

enum LearnerAudience: String, Codable, CaseIterable {
    case child
    case adult
    case general
}

enum LearningStage: String, Codable, CaseIterable {
    case example
    case practice
    case action
    case challenge

    func displayLabel(isHiraganaMode: Bool) -> String {
        switch self {
        case .example: isHiraganaMode ? "おてほん" : "お手本"
        case .practice: isHiraganaMode ? "れんしゅう" : "練習"
        case .action: isHiraganaMode ? "つぎの こうどう" : "次の行動"
        case .challenge: isHiraganaMode ? "うでだめし" : "腕試し"
        }
    }
}

enum LearningFocus: String, Codable, CaseIterable {
    case pause
    case evidence
    case verify
    case consult

    func prompt(isHiraganaMode: Bool) -> String {
        switch self {
        case .pause: isHiraganaMode ? "いそがされて いないかな？" : "急がされていないかな？"
        case .evidence: isHiraganaMode ? "そう いえる りゆうは あるかな？" : "そう言える理由はあるかな？"
        case .verify: isHiraganaMode ? "どうやって たしかめよう？" : "どうやって確かめよう？"
        case .consult: isHiraganaMode ? "だれに そうだん できるかな？" : "だれに相談できるかな？"
        }
    }
}

enum QuestionResponseType: String, Codable, CaseIterable {
    case selectSegments
    case singleChoice
}

enum AnswerChoiceSemantic: String, Codable, CaseIterable {
    case suspicious
    case noIssueFound
    case insufficientInformation
    case pause
    case verifySource
    case consultTrustedPerson
    case other
}

struct AnswerChoice: Identifiable, Codable, Hashable {
    let id: String
    let text: String
    let phoneticText: String?
    let semantic: AnswerChoiceSemantic

    init(
        id: String,
        text: String,
        phoneticText: String? = nil,
        semantic: AnswerChoiceSemantic = .other
    ) {
        self.id = id
        self.text = text
        self.phoneticText = phoneticText
        self.semantic = semantic
    }

    func displayText(isHiraganaMode: Bool) -> String {
        if isHiraganaMode, let phoneticText {
            return phoneticText
        }
        return text
    }
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
    let selectedChoiceId: String?
    let responseType: QuestionResponseType
    let score: Int
    let isPerfect: Bool
    let hintUsed: Bool
    let attemptNumber: Int
    let learningStage: LearningStage
    let contentRevision: Int
    let answeredAt: Date

    var isFirstTryIndependent: Bool {
        isPerfect && attemptNumber == 1 && !hintUsed && learningStage != .example
    }

    init(
        questionId: String,
        selectedSegmentIds: [String],
        selectedReasonTags: [ReasonTag],
        selectedChoiceId: String? = nil,
        responseType: QuestionResponseType = .selectSegments,
        score: Int,
        isPerfect: Bool,
        hintUsed: Bool = false,
        attemptNumber: Int = 1,
        learningStage: LearningStage = .challenge,
        contentRevision: Int = 1,
        answeredAt: Date
    ) {
        self.questionId = questionId
        self.selectedSegmentIds = selectedSegmentIds
        self.selectedReasonTags = selectedReasonTags
        self.selectedChoiceId = selectedChoiceId
        self.responseType = responseType
        self.score = score
        self.isPerfect = isPerfect
        self.hintUsed = hintUsed
        self.attemptNumber = max(attemptNumber, 1)
        self.learningStage = learningStage
        self.contentRevision = max(contentRevision, 1)
        self.answeredAt = answeredAt
    }

    enum CodingKeys: String, CodingKey {
        case questionId
        case selectedSegmentIds
        case selectedReasonTags
        case selectedChoiceId
        case responseType
        case score
        case isPerfect
        case hintUsed
        case attemptNumber
        case learningStage
        case contentRevision
        case answeredAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        questionId = try container.decode(String.self, forKey: .questionId)
        selectedSegmentIds = try container.decodeIfPresent([String].self, forKey: .selectedSegmentIds) ?? []
        selectedReasonTags = try container.decodeIfPresent([ReasonTag].self, forKey: .selectedReasonTags) ?? []
        selectedChoiceId = try container.decodeIfPresent(String.self, forKey: .selectedChoiceId)
        responseType = try container.decodeIfPresent(QuestionResponseType.self, forKey: .responseType) ?? .selectSegments
        score = try container.decode(Int.self, forKey: .score)
        isPerfect = try container.decode(Bool.self, forKey: .isPerfect)
        hintUsed = try container.decodeIfPresent(Bool.self, forKey: .hintUsed) ?? false
        attemptNumber = max(try container.decodeIfPresent(Int.self, forKey: .attemptNumber) ?? 1, 1)
        learningStage = try container.decodeIfPresent(LearningStage.self, forKey: .learningStage) ?? .challenge
        contentRevision = max(try container.decodeIfPresent(Int.self, forKey: .contentRevision) ?? 1, 1)
        answeredAt = try container.decode(Date.self, forKey: .answeredAt)
    }
}

struct UserStats: Codable, Hashable {
    var totalChallenges: Int = 0
    var correctAnswers: Int = 0
    var perfectAnswers: Int = 0
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var totalScore: Int = 0
    var independentCorrectAnswers: Int = 0

    init(
        totalChallenges: Int = 0,
        correctAnswers: Int = 0,
        perfectAnswers: Int = 0,
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        totalScore: Int = 0,
        independentCorrectAnswers: Int = 0
    ) {
        self.totalChallenges = totalChallenges
        self.correctAnswers = correctAnswers
        self.perfectAnswers = perfectAnswers
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.totalScore = totalScore
        self.independentCorrectAnswers = independentCorrectAnswers
    }

    enum CodingKeys: String, CodingKey {
        case totalChallenges
        case correctAnswers
        case perfectAnswers
        case currentStreak
        case bestStreak
        case totalScore
        case independentCorrectAnswers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalChallenges = try container.decodeIfPresent(Int.self, forKey: .totalChallenges) ?? 0
        correctAnswers = try container.decodeIfPresent(Int.self, forKey: .correctAnswers) ?? 0
        perfectAnswers = try container.decodeIfPresent(Int.self, forKey: .perfectAnswers) ?? 0
        currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        bestStreak = try container.decodeIfPresent(Int.self, forKey: .bestStreak) ?? 0
        totalScore = try container.decodeIfPresent(Int.self, forKey: .totalScore) ?? 0
        independentCorrectAnswers = try container.decodeIfPresent(Int.self, forKey: .independentCorrectAnswers) ?? 0
    }
}

struct ModeCard: Identifiable {
    let id = UUID()
    let mode: GameMode
    let difficulty: Difficulty
}
