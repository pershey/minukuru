import SwiftUI

struct ResultView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let viewModel: QuizSessionViewModel
    let result: QuizEvaluation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("結果")
                        .font(.headline)
                        .foregroundStyle(MinukuruTheme.primary)
                    Text(result.encouragement)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text(result.scoreMessage)
                        .font(.title3)
                    Text("獲得ポイント: \(result.result.score)")
                        .font(.title2.weight(.bold))
                        .padding(.top, 6)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MinukuruTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                ResultSection(title: "えらんだ箇所") {
                    if result.selectedSegments.isEmpty {
                        Text("今回は選択なしでした。")
                    } else {
                        ForEach(result.selectedSegments) { segment in
                            ResultLine(text: segment.text, symbol: "hand.tap.fill")
                        }
                    }
                }

                ResultSection(title: "本当にあやしかった箇所") {
                    ForEach(result.correctSegments) { segment in
                        ResultLine(text: segment.text, symbol: "magnifyingglass.circle.fill")
                    }
                }

                if !result.missedSegments.isEmpty {
                    ResultSection(title: "見逃した箇所") {
                        ForEach(result.missedSegments) { segment in
                            ResultLine(text: segment.text, symbol: "eye.slash.fill")
                        }
                    }
                }

                if !result.wrongSegments.isEmpty {
                    ResultSection(title: "今回はちがった箇所") {
                        ForEach(result.wrongSegments) { segment in
                            ResultLine(text: segment.text, symbol: "arrow.uturn.backward.circle.fill")
                        }
                    }
                }

                ResultSection(title: "やさしい解説") {
                    Text(viewModel.question.explanation)
                        .font(.title3)
                }

                ResultSection(title: "どう確認すればよかったか") {
                    Text(viewModel.question.verificationTip)
                        .font(.title3)
                }

                ResultSection(title: "選んだ理由タグ") {
                    if result.result.selectedReasonTags.isEmpty {
                        Text("理由タグはまだ選んでいません。次は気になるタグも押してみよう。")
                            .font(.title3)
                    } else {
                        ForEach(result.result.selectedReasonTags, id: \.self) { tag in
                            ResultLine(text: tag.label, symbol: "tag.fill")
                        }
                    }
                }

                VStack(spacing: 12) {
                    Button {
                        appViewModel.startQuiz(for: viewModel.question.mode)
                    } label: {
                        Label("次の問題へ", systemImage: "arrow.right.circle.fill")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(MinukuruTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Button {
                        appViewModel.showModes()
                    } label: {
                        Label("モード選択へ戻る", systemImage: "square.grid.2x2.fill")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MinukuruTheme.primary)
                    .background(MinukuruTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(20)
        }
    }
}

private struct ResultSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.weight(.bold))
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct ResultLine: View {
    let text: String
    let symbol: String

    var body: some View {
        Label {
            Text(text)
                .font(.title3)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(MinukuruTheme.primary)
        }
    }
}
