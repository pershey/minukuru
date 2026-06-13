import SwiftUI

struct ResultView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let viewModel: QuizSessionViewModel
    let result: QuizEvaluation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(appViewModel.settings.isHiraganaMode ? "けっか" : "結果")
                        .font(.headline)
                        .foregroundStyle(MinukuruTheme.primary)
                    Text(result.encouragement)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text(result.scoreMessage)
                        .font(.title3)
                    Text(appViewModel.settings.isHiraganaMode ? "ポイント: \(result.result.score)" : "獲得ポイント: \(result.result.score)")
                        .font(.title2.weight(.bold))
                        .padding(.top, 6)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MinukuruTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                ResultSection(title: appViewModel.settings.isHiraganaMode ? "えらんだ ばしょ" : "えらんだ箇所") {
                    if result.selectedSegments.isEmpty {
                        Text("今回は選択なしでした。")
                    } else {
                        ForEach(result.selectedSegments) { segment in
                            ResultLine(text: segment.displayText(isHiraganaMode: appViewModel.settings.isHiraganaMode), symbol: "hand.tap.fill")
                        }
                    }
                }

                ResultSection(title: appViewModel.settings.isHiraganaMode ? "ほんとうに あやしかった ばしょ" : "本当にあやしかった箇所") {
                    ForEach(result.correctSegments) { segment in
                        ResultLine(text: segment.displayText(isHiraganaMode: appViewModel.settings.isHiraganaMode), symbol: "magnifyingglass.circle.fill")
                    }
                }

                if !result.missedSegments.isEmpty {
                    ResultSection(title: appViewModel.settings.isHiraganaMode ? "みのがした ばしょ" : "見逃した箇所") {
                        ForEach(result.missedSegments) { segment in
                            ResultLine(text: segment.displayText(isHiraganaMode: appViewModel.settings.isHiraganaMode), symbol: "eye.slash.fill")
                        }
                    }
                }

                if !result.wrongSegments.isEmpty {
                    ResultSection(title: appViewModel.settings.isHiraganaMode ? "こんかいは ちがった ばしょ" : "今回はちがった箇所") {
                        ForEach(result.wrongSegments) { segment in
                            ResultLine(text: segment.displayText(isHiraganaMode: appViewModel.settings.isHiraganaMode), symbol: "arrow.uturn.backward.circle.fill")
                        }
                    }
                }

                ResultSection(title: appViewModel.settings.isHiraganaMode ? "やさしい かいせつ" : "やさしい解説") {
                    Text(viewModel.question.displayExplanation(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                        .font(.title3)
                }

                ResultSection(title: appViewModel.settings.isHiraganaMode ? "どう かくにん すれば よかったか" : "どう確認すればよかったか") {
                    Text(viewModel.question.displayVerificationTip(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                        .font(.title3)
                }

                ResultSection(title: appViewModel.settings.isHiraganaMode ? "えらんだ りゆうタグ" : "選んだ理由タグ") {
                    if result.result.selectedReasonTags.isEmpty {
                        Text(appViewModel.settings.isHiraganaMode ? "りゆうタグは まだ えらんでいません。つぎは きになる タグも おしてみよう。" : "理由タグはまだ選んでいません。次は気になるタグも押してみよう。")
                            .font(.title3)
                    } else {
                        ForEach(result.result.selectedReasonTags, id: \.self) { tag in
                            ResultLine(text: tag.displayLabel(isHiraganaMode: appViewModel.settings.isHiraganaMode), symbol: "tag.fill")
                        }
                    }
                }

                ResultSection(title: appViewModel.settings.isHiraganaMode ? "みかたの ふりかえり" : "見方のふり返り") {
                    Text(result.reasoningMessage)
                        .font(.title3)

                    if !result.matchedReasonTags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                                Text(appViewModel.settings.isHiraganaMode ? "こんかいの みかたで あっていたもの" : "今回の見方で合っていたもの")
                                .font(.headline)
                                .foregroundStyle(MinukuruTheme.primary)
                            ForEach(result.matchedReasonTags, id: \.self) { tag in
                                ResultLine(text: tag.displayLabel(isHiraganaMode: appViewModel.settings.isHiraganaMode), symbol: "checkmark.circle.fill")
                            }
                        }
                    }

                    if !result.missedRecommendedTags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                                Text(appViewModel.settings.isHiraganaMode ? "こんかいは ここにも ちゅうもくできると よかった" : "今回はここにも注目できるとよかった")
                                .font(.headline)
                                .foregroundStyle(MinukuruTheme.primary)
                            ForEach(result.missedRecommendedTags, id: \.self) { tag in
                                ResultLine(text: tag.displayLabel(isHiraganaMode: appViewModel.settings.isHiraganaMode), symbol: "lightbulb.fill")
                            }
                        }
                    }

                    if !result.offTargetReasonTags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                                Text(appViewModel.settings.isHiraganaMode ? "こんかいの もんだいでは すこし ちがった みかた" : "今回の問題では少しちがった見方")
                                .font(.headline)
                                .foregroundStyle(MinukuruTheme.primary)
                            ForEach(result.offTargetReasonTags, id: \.self) { tag in
                                ResultLine(text: tag.displayLabel(isHiraganaMode: appViewModel.settings.isHiraganaMode), symbol: "arrow.trianglehead.2.clockwise.rotate.90")
                            }
                        }
                    }
                }

                VStack(spacing: 12) {
                    Button {
                        appViewModel.startPractice()
                    } label: {
                        Label(appViewModel.settings.isHiraganaMode ? "つぎの もんだいへ" : "次の問題へ", systemImage: "arrow.right.circle.fill")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(MinukuruTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Button {
                        appViewModel.goHome()
                    } label: {
                        Label(appViewModel.settings.isHiraganaMode ? "タイトルへ もどる" : "タイトルへ戻る", systemImage: "house.fill")
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
