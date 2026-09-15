import SwiftUI

struct QuizView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject var viewModel: QuizSessionViewModel
    @AccessibilityFocusState private var isStepHeadingFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                topBar
                learningHeader
                questionCard
                ReadAloudControls(
                    text: spokenQuestionText,
                    isHiraganaMode: appViewModel.settings.isHiraganaMode
                )

                if viewModel.phase == .reason {
                    reasonStep
                }

                actionArea
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .alert("ヒント", isPresented: $viewModel.isHintPresented) {
            Button(appViewModel.settings.isHiraganaMode ? "とじる" : "閉じる", role: .cancel) { }
        } message: {
            Text(viewModel.question.displayHint(isHiraganaMode: appViewModel.settings.isHiraganaMode))
        }
        .onChange(of: viewModel.phase) { _, _ in
            isStepHeadingFocused = true
        }
    }

    private var topBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                modeSelectionButton
                Spacer()
                modeTitle
            }

            VStack(alignment: .leading, spacing: 4) {
                modeSelectionButton
                modeTitle
            }
        }
    }

    private var modeSelectionButton: some View {
        Button {
            appViewModel.showModes()
        } label: {
            Label(
                appViewModel.settings.isHiraganaMode ? "モードせんたくへ" : "モード選択へ",
                systemImage: "chevron.left"
            )
            .font(.headline.weight(.bold))
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MinukuruTheme.primary)
    }

    private var modeTitle: some View {
        Text(viewModel.question.mode.displayTitle(isHiraganaMode: appViewModel.settings.isHiraganaMode))
            .font(.headline.weight(.bold))
            .foregroundStyle(MinukuruTheme.modeAccent(viewModel.question.mode))
            .multilineTextAlignment(.leading)
    }

    private var learningHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.question.learningStage.displayLabel(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MinukuruTheme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(MinukuruTheme.accentSoft)
                .clipShape(Capsule())

            Text(stepHeading)
                .font(.title2.weight(.bold))
                .foregroundStyle(MinukuruTheme.primary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($isStepHeadingFocused)

            Text(viewModel.question.learningFocus.prompt(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                .font(.body.weight(.semibold))
                .foregroundStyle(MinukuruTheme.muted)
        }
    }

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(viewModel.question.displayTitle(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                .font(.headline.weight(.bold))
                .foregroundStyle(MinukuruTheme.modeAccent(viewModel.question.mode))
                .accessibilityAddTraits(.isHeader)

            Text(viewModel.question.displayInstruction(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                .font(.body)
                .foregroundStyle(MinukuruTheme.muted)

            if viewModel.question.responseType == .selectSegments {
                SegmentFlowLayout(horizontalSpacing: 10, verticalSpacing: 12) {
                    ForEach(viewModel.question.segments) { segment in
                        let isSelected = viewModel.selectedSegmentIds.contains(segment.id)
                        InlineSegmentChip(
                            text: segment.displayText(isHiraganaMode: appViewModel.settings.isHiraganaMode),
                            isSelected: isSelected
                        ) {
                            viewModel.toggleSegment(segment.id)
                        }
                        .accessibilityLabel(segmentAccessibilityLabel(segment, isSelected: isSelected))
                        .accessibilityValue(isSelected ? "選択中" : "未選択")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .disabled(viewModel.phase != .answer || viewModel.isGuidedExample)
                    }
                }

                if !viewModel.selectedSegmentIds.isEmpty, !viewModel.isGuidedExample {
                    Label(
                        appViewModel.settings.isHiraganaMode
                            ? "せんたくすう \(viewModel.selectedSegmentIds.count)こ"
                            : "選択数 \(viewModel.selectedSegmentIds.count)個",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MinukuruTheme.primary)
                    .accessibilityElement(children: .combine)
                }
            } else {
                Text(viewModel.question.displayFullText(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                    .font(.body)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(viewModel.question.answerChoices) { choice in
                        answerChoiceButton(choice)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.94))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MinukuruTheme.modeAccent(viewModel.question.mode).opacity(0.28), lineWidth: 1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var reasonStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(appViewModel.settings.isHiraganaMode ? "どの みかたが ちかい？" : "どの見方が近い？")
                .font(.title2.weight(.bold))
                .foregroundStyle(MinukuruTheme.primary)
                .accessibilityAddTraits(.isHeader)

            Text(appViewModel.settings.isHiraganaMode
                 ? "いちばん ちかい りゆうを ひとつ えらびます。"
                 : "いちばん近い理由を1つ選びます。")
                .font(.body)
                .foregroundStyle(MinukuruTheme.muted)

            VStack(spacing: 10) {
                ForEach(viewModel.recommendedTags) { tag in
                    ReasonTagChip(
                        title: tag.displayLabel(isHiraganaMode: appViewModel.settings.isHiraganaMode),
                        isSelected: viewModel.selectedReasonTags.contains(tag)
                    ) {
                        viewModel.selectReason(tag)
                    }
                    .accessibilityLabel(tag.displayLabel(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                    .accessibilityValue(viewModel.selectedReasonTags.contains(tag) ? "選択中" : "未選択")
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MinukuruTheme.accentSoft.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var actionArea: some View {
        VStack(spacing: 12) {
            Button {
                viewModel.showHint()
            } label: {
                Label(
                    appViewModel.settings.isHiraganaMode ? "わからない・ヒントを みる" : "わからない・ヒントを見る",
                    systemImage: "lightbulb"
                )
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.plain)
            .foregroundStyle(MinukuruTheme.primary)
            .background(Color.white.opacity(0.94))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MinukuruTheme.stroke, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityHint("ヒントを表示します。情報不足という答えとは別の操作です")

            Button {
                viewModel.performPrimaryAction()
            } label: {
                Label(viewModel.primaryActionTitle, systemImage: "arrow.right.circle.fill")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(viewModel.canSubmit ? MinukuruTheme.primary : Color.gray.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .disabled(!viewModel.canSubmit)
            .accessibilityHint(primaryActionHint)
        }
    }

    private func answerChoiceButton(_ choice: AnswerChoice) -> some View {
        let isSelected = viewModel.selectedChoiceId == choice.id
        return Button {
            viewModel.selectChoice(choice.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .accessibilityHidden(true)
                Text(choice.displayText(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundStyle(MinukuruTheme.primary)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background {
                if isSelected {
                    MinukuruTheme.accentSoft
                } else {
                    MinukuruTheme.background
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? MinukuruTheme.primary : MinukuruTheme.stroke, lineWidth: isSelected ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.displayText(isHiraganaMode: appViewModel.settings.isHiraganaMode))
        .accessibilityValue(isSelected ? "選択中" : "未選択")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var stepHeading: String {
        if viewModel.phase == .reason {
            return appViewModel.settings.isHiraganaMode ? "ステップ2 りゆうを かんがえる" : "ステップ2 理由を考える"
        }
        if viewModel.isGuidedExample {
            return appViewModel.settings.isHiraganaMode ? "きをつける ところを みてみよう" : "気をつけるところを見てみよう"
        }
        return appViewModel.settings.isHiraganaMode ? "ステップ1 ぶんしょうを よむ" : "ステップ1 文章を読む"
    }

    private var primaryActionHint: String {
        if viewModel.phase == .answer, viewModel.question.responseType == .selectSegments, !viewModel.isGuidedExample {
            return "選んだ箇所はまだ採点せず、理由を選ぶ画面へ進みます"
        }
        return "自動では次の問題へ進まず、答えと解説を表示します"
    }

    private var spokenQuestionText: String {
        [
            viewModel.question.displayTitle(isHiraganaMode: appViewModel.settings.isHiraganaMode),
            viewModel.question.displayInstruction(isHiraganaMode: appViewModel.settings.isHiraganaMode),
            viewModel.question.displayFullText(isHiraganaMode: appViewModel.settings.isHiraganaMode),
            viewModel.question.responseType == .singleChoice
                ? viewModel.question.answerChoices.map { $0.displayText(isHiraganaMode: appViewModel.settings.isHiraganaMode) }.joined(separator: "。")
                : ""
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "。")
    }

    private func segmentAccessibilityLabel(_ segment: TextSegment, isSelected: Bool) -> String {
        let text = segment.displayText(isHiraganaMode: appViewModel.settings.isHiraganaMode)
        if viewModel.isGuidedExample {
            return "\(text)。お手本で注目する箇所"
        }
        return "\(text)。\(isSelected ? "選択中" : "未選択")"
    }
}
