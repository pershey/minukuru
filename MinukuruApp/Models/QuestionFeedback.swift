import Foundation

enum QuestionFeedbackKind: String, CaseIterable, Identifiable {
    case explanation, answer, reading, other
    var id: String { rawValue }

    func label(hiragana: Bool) -> String {
        switch self {
        case .explanation: hiragana ? "せつめいが わかりにくい" : "説明がわかりにくい"
        case .answer: hiragana ? "こたえについて つたえたい" : "答えについて伝えたい"
        case .reading: hiragana ? "もじや よみかたについて" : "文字や読み方について"
        case .other: hiragana ? "そのほか" : "その他"
        }
    }
}

struct QuestionFeedback {
    static let recipient = "pershey_1228@icloud.com"
    let questionID: String
    let contentRevision: Int
    let kind: QuestionFeedbackKind
    let note: String
    let appVersion: String
    let build: String

    init(questionID: String, contentRevision: Int, kind: QuestionFeedbackKind, note: String,
         appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "不明",
         build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "不明") {
        self.questionID = questionID
        self.contentRevision = contentRevision
        self.kind = kind
        self.note = note
        self.appVersion = appVersion
        self.build = build
    }

    // 履歴、購入情報、端末識別子、問題の本文は添付しない。
    var message: String {
        """
        ミヌクルの問題について
        種類: \(kind.label(hiragana: false))
        問題ID: \(questionID)
        問題の版: \(contentRevision)
        アプリ: \(appVersion) (\(build))

        \(note.trimmingCharacters(in: .whitespacesAndNewlines))
        """
    }

    var mailURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.recipient
        components.queryItems = [URLQueryItem(name: "subject", value: "ミヌクルの問題について"),
                                 URLQueryItem(name: "body", value: message)]
        return components.url
    }
}
