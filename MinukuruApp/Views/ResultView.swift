import SwiftUI

struct ResultView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let viewModel: QuizSessionViewModel
    let result: QuizEvaluation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                resultHeader
                originalTextSection
                answerSection
                explanationSection
                ReadAloudControls(
                    text: spokenResultText,
                    isHiraganaMode: appViewModel.settings.isHiraganaMode
                )
                actionButtons
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    private var resultHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(resultTitle, systemImage: resultIcon)
                .font(.title2.weight(.bold))
                .foregroundStyle(MinukuruTheme.primary)
                .accessibilityAddTraits(.isHeader)

            Text(result.encouragement)
                .font(.title3.weight(.semibold))
                .foregroundStyle(MinukuruTheme.primary)

            Text(result.scoreMessage)
                .font(.body)
                .foregroundStyle(MinukuruTheme.muted)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    resultMetadata
                }

                VStack(alignment: .leading, spacing: 8) {
                    resultMetadata
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(MinukuruTheme.muted)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MinukuruTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private var resultMetadata: some View {
        Label(
            appViewModel.settings.isHiraganaMode
                ? "がくしゅうポイント \(result.result.score)"
                : "学習ポイント \(result.result.score)",
            systemImage: "book.closed.fill"
        )
        if result.result.hintUsed {
            Label(appViewModel.settings.isHiraganaMode ? "ヒント しよう" : "ヒント使用", systemImage: "lightbulb.fill")
        }
        if result.result.attemptNumber > 1 {
            Label("\(result.result.attemptNumber)回目", systemImage: "arrow.counterclockwise")
        }
    }

    private var originalTextSection: some View {
        ResultSection(title: appViewModel.settings.isHiraganaMode ? "もとの ぶんしょう" : "元の文章") {
            Text(viewModel.question.displayFullText(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                .font(.body)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var answerSection: some View {
        if viewModel.question.learningStage == .example {
            EmptyView()
        } else if viewModel.question.responseType == .singleChoice {
            ResultSection(title: appViewModel.settings.isHiraganaMode ? "こたえを くらべる" : "答えを比べる") {
                answerLine(
                    label: appViewModel.settings.isHiraganaMode ? "えらんだ こたえ" : "選んだ答え",
                    text: result.selectedChoice?.displayText(isHiraganaMode: appViewModel.settings.isHiraganaMode) ?? "未選択",
                    symbol: "hand.tap"
                )
                answerLine(
                    label: appViewModel.settings.isHiraganaMode ? "この もんだいの こたえ" : "この問題の答え",
                    text: result.correctChoice?.displayText(isHiraganaMode: appViewModel.settings.isHiraganaMode) ?? "確認できません",
                    symbol: "checkmark.circle"
                )
            }
        } else {
            ResultSection(title: appViewModel.settings.isHiraganaMode ? "ばしょを くらべる" : "箇所を比べる") {
                segmentGroup(
                    title: appViewModel.settings.isHiraganaMode ? "えらんだ ばしょ" : "選んだ箇所",
                    segments: result.selectedSegments,
                    emptyText: appViewModel.settings.isHiraganaMode ? "えらんだ ばしょは ありません。" : "選んだ箇所はありません。",
                    symbol: "hand.tap"
                )
                Divider()
                segmentGroup(
                    title: appViewModel.settings.isHiraganaMode ? "ちゅうもくする ばしょ" : "注目する箇所",
                    segments: result.correctSegments,
                    emptyText: appViewModel.settings.isHiraganaMode ? "とくに もんだいの ある ひょうげんは ありません。" : "特に問題のある表現はありません。",
                    symbol: "magnifyingglass"
                )
            }
        }
    }

    private var explanationSection: some View {
        ResultSection(title: appViewModel.settings.isHiraganaMode ? "かんがえかた" : "考え方") {
            explanationBlock(
                title: appViewModel.settings.isHiraganaMode ? "1. どこに ちゅうもくする？" : "1. どこに注目する？",
                text: viewModel.question.displayAttentionPoint(isHiraganaMode: appViewModel.settings.isHiraganaMode),
                symbol: "eye"
            )
            explanationBlock(
                title: appViewModel.settings.isHiraganaMode ? "2. なぜ きをつける？" : "2. なぜ気をつける？",
                text: viewModel.question.displayExplanation(isHiraganaMode: appViewModel.settings.isHiraganaMode),
                symbol: "questionmark.circle"
            )
            explanationBlock(
                title: appViewModel.settings.isHiraganaMode ? "3. つぎに どうする？" : "3. 次にどうする？",
                text: viewModel.question.displayVerificationTip(isHiraganaMode: appViewModel.settings.isHiraganaMode),
                symbol: "checklist"
            )

            if viewModel.question.responseType == .selectSegments,
               !viewModel.question.recommendedReasonTags.isEmpty {
                Divider()
                Text(appViewModel.settings.isHiraganaMode ? "つかえる みかた" : "使える見方")
                    .font(.headline.weight(.bold))
                ForEach(viewModel.question.recommendedReasonTags, id: \.self) { tag in
                    Label(tag.displayLabel(isHiraganaMode: appViewModel.settings.isHiraganaMode), systemImage: "tag")
                        .font(.body)
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                appViewModel.startNextQuestion(after: viewModel.question)
            } label: {
                Label(appViewModel.settings.isHiraganaMode ? "おなじ テーマの つぎへ" : "同じテーマの次へ", systemImage: "arrow.right.circle.fill")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(MinukuruTheme.primary)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                appViewModel.retry(viewModel.question)
            } label: {
                Label(appViewModel.settings.isHiraganaMode ? "この もんだいを もういちど" : "この問題をもう一度", systemImage: "arrow.counterclockwise")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.plain)
            .foregroundStyle(MinukuruTheme.primary)
            .background(Color.white.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                appViewModel.showModes()
            } label: {
                Label(appViewModel.settings.isHiraganaMode ? "モードせんたくへ" : "モード選択へ", systemImage: "square.grid.2x2")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.plain)
            .foregroundStyle(MinukuruTheme.primary)
            .background(MinukuruTheme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var resultTitle: String {
        if viewModel.question.learningStage == .example {
            return appViewModel.settings.isHiraganaMode ? "おてほん" : "お手本"
        }
        return result.result.isPerfect
            ? (appViewModel.settings.isHiraganaMode ? "こたえが あっています" : "答えが合っています")
            : (appViewModel.settings.isHiraganaMode ? "こたえを かくにんしよう" : "答えを確認しよう")
    }

    private var resultIcon: String {
        viewModel.question.learningStage == .example || result.result.isPerfect
            ? "checkmark.circle.fill"
            : "book.circle.fill"
    }

    private var spokenResultText: String {
        [
            resultTitle,
            appViewModel.settings.isHiraganaMode ? "もとの ぶんしょう" : "元の文章",
            viewModel.question.displayFullText(isHiraganaMode: appViewModel.settings.isHiraganaMode),
            viewModel.question.displayAttentionPoint(isHiraganaMode: appViewModel.settings.isHiraganaMode),
            viewModel.question.displayExplanation(isHiraganaMode: appViewModel.settings.isHiraganaMode),
            viewModel.question.displayVerificationTip(isHiraganaMode: appViewModel.settings.isHiraganaMode)
        ].joined(separator: "。")
    }

    private func answerLine(label: String, text: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(label, systemImage: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(MinukuruTheme.primary)
            Text(text)
                .font(.body)
                .padding(.leading, 28)
        }
        .accessibilityElement(children: .combine)
    }

    private func segmentGroup(title: String, segments: [TextSegment], emptyText: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(MinukuruTheme.primary)
            if segments.isEmpty {
                Text(emptyText)
                    .font(.body)
            } else {
                ForEach(segments) { segment in
                    Text(segment.displayText(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                        .font(.body)
                        .padding(.leading, 28)
                }
            }
        }
    }

    private func explanationBlock(title: String, text: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(MinukuruTheme.primary)
            Text(text)
                .font(.body)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ResultSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(MinukuruTheme.primary)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
