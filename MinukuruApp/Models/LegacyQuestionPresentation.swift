enum LegacyQuestionPresentation {
    // 旧版の教材を1.1で表示するときだけ適用する。問題や箇所のIDは維持する。
    private static let orders: [String: [String]] = [
        "newsPoison_011": ["s1", "s4", "s2", "s3"],
        "newsPoison_012": ["s1", "s2", "s4", "s3"],
        "newsPoison_013": ["s1", "s4", "s2", "s3"],
        "newsPoison_014": ["s1", "s4", "s3", "s2"],
        "newsPoison_015": ["s1", "s2", "s4", "s3"],
        "newsPoison_016": ["s1", "s4", "s2", "s3"],
        "newsPoison_017": ["s1", "s4", "s2", "s3"],
        "newsPoison_018": ["s1", "s2", "s4", "s3"],
        "newsPoison_019": ["s1", "s2", "s4", "s3"],
        "scamAdChecker_015": ["s1", "s3", "s4", "s2"],
        "scamAdChecker_016": ["s1", "s4", "s2", "s3", "s5"],
        "scamAdChecker_017": ["s1", "s3", "s2", "s4"],
        "scamAdChecker_019": ["s1", "s3", "s2", "s4"],
        "scamAdChecker_020": ["s1", "s4", "s2", "s3", "s5"]
    ]

    static func includes(_ question: QuizQuestion) -> Bool {
        // 理由のある期限まで誤りとする旧問は、修正版が届くまで出題しない。
        question.contentRevision > 1
            || !["scamAdChecker_011", "scamAdChecker_014"].contains(question.id)
    }

    static func segments(for question: QuizQuestion) -> [TextSegment] {
        guard question.contentRevision == 1, let order = orders[question.id],
              question.segments.map(\.id) == order.sorted() else { return question.segments }
        return order.compactMap { id in question.segments.first { $0.id == id } }
    }
}
