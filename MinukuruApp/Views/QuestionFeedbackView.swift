import SwiftUI

struct QuestionFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    let question: QuizQuestion
    let isHiraganaMode: Bool
    @State private var kind: QuestionFeedbackKind = .explanation
    @State private var note = ""

    private var feedback: QuestionFeedback {
        QuestionFeedback(questionID: question.id, contentRevision: question.contentRevision, kind: kind, note: note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(question.displayTitle(isHiraganaMode: isHiraganaMode))
                    Picker(isHiraganaMode ? "つたえたい こと" : "伝えたいこと", selection: $kind) {
                        ForEach(QuestionFeedbackKind.allCases) { item in
                            Text(item.label(hiragana: isHiraganaMode)).tag(item)
                        }
                    }
                    TextField(isHiraganaMode ? "きになった ところ（かかなくても だいじょうぶ）" : "気になったところ（任意）",
                              text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: note) { _, value in
                            if value.count > 1000 { note = String(value.prefix(1000)) }
                        }
                    Text(isHiraganaMode ? "なまえや じゅうしょは かかないでね。いえの ひとと いっしょに つたえても だいじょうぶ。" : "名前や住所は書かずに、気になったところを教えてください。家の人と一緒に伝えても大丈夫です。")
                        .font(.footnote)
                }
                Section(isHiraganaMode ? "つたえる ないよう" : "伝える内容") {
                    Text(feedback.message)
                        .font(.body)
                        .textSelection(.enabled)
                }
                Section {
                    if let url = feedback.mailURL {
                        Link(destination: url) {
                            Label(isHiraganaMode ? "メールを ひらく" : "メールを開く", systemImage: "envelope")
                                .frame(minHeight: 44)
                        }
                    }
                    ShareLink(item: feedback.message) {
                        Label(isHiraganaMode ? "ほかの ほうほうで つたえる" : "ほかの方法で伝える", systemImage: "square.and.arrow.up")
                            .frame(minHeight: 44)
                    }
                    Text(isHiraganaMode ? "おくる まえに ないようを かくにんできます。" : "送信前に内容を確認できます。")
                        .font(.footnote)
                }
            }
            .navigationTitle(isHiraganaMode ? "きづいた ことを つたえる" : "気づいたことを伝える")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isHiraganaMode ? "とじる" : "閉じる") { dismiss() }
                }
            }
        }
    }
}
