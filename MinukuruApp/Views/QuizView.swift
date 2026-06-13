import SwiftUI

struct QuizView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject var viewModel: QuizSessionViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button(appViewModel.settings.isHiraganaMode ? "モードせんたくへ" : "モード選択へ") {
                        appViewModel.showModes()
                    }
                    .font(.headline.bold())
                    .foregroundStyle(MinukuruTheme.primary)

                    Spacer()
                }

                VStack(spacing: 8) {
                    Text(viewModel.question.mode.displayTitle(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(MinukuruTheme.modeAccent(viewModel.question.mode))
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text(viewModel.question.mode.displayShortDescription(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MinukuruTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                VStack(alignment: .leading, spacing: 14) {
                    QuestionStemCard(viewModel: viewModel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 14) {
                    Text(appViewModel.settings.isHiraganaMode ? "りゆうタグ" : "理由タグ")
                        .font(.title2.weight(.bold))
                    Text(appViewModel.settings.isHiraganaMode ? "どうして あやしいと おもったか、ちかいものを えらんでね。" : "どうして怪しいと思ったか、近いものを選んでね。")
                        .font(.body)
                        .foregroundStyle(MinukuruTheme.muted)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                        ForEach(viewModel.recommendedTags) { tag in
                            ReasonTagChip(title: tag.displayLabel(isHiraganaMode: appViewModel.settings.isHiraganaMode), isSelected: viewModel.selectedReasonTags.contains(tag)) {
                                viewModel.toggleTag(tag)
                            }
                            .accessibilityLabel(tag.displayLabel(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                            .accessibilityValue(viewModel.selectedReasonTags.contains(tag) ? "選択中" : "未選択")
                        }
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                HStack(spacing: 12) {
                    Button {
                        viewModel.isHintPresented = true
                    } label: {
                        Label(appViewModel.settings.isHiraganaMode ? "ヒント" : "ヒント", systemImage: "lightbulb.fill")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MinukuruTheme.primary)
                    .background(Color.white.opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityLabel("ヒントを表示")

                    Button {
                        viewModel.submit()
                    } label: {
                        Label(appViewModel.settings.isHiraganaMode ? "こたえあわせ" : "答え合わせ", systemImage: "checkmark.seal.fill")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(viewModel.canSubmit ? MinukuruTheme.primary : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .disabled(!viewModel.canSubmit)
                    .accessibilityLabel("答え合わせ")
                }

                if !appViewModel.hasPremiumAccess {
                    BannerAdView()
                }
            }
            .padding(20)
        }
        .alert(appViewModel.settings.isHiraganaMode ? "ヒント" : "ヒント", isPresented: $viewModel.isHintPresented) {
            Button(appViewModel.settings.isHiraganaMode ? "とじる" : "とじる", role: .cancel) { }
        } message: {
            Text(viewModel.question.displayHint(isHiraganaMode: appViewModel.settings.isHiraganaMode))
        }
    }
}

private struct QuestionStemCard: View {
    @ObservedObject var viewModel: QuizSessionViewModel

    var body: some View {
        Group {
            if viewModel.question.mode == .scamAdChecker {
                ScamAdStemView(viewModel: viewModel)
            } else {
                InlineQuestionStemView(viewModel: viewModel)
            }
        }
    }
}

private struct InlineQuestionStemView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject var viewModel: QuizSessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.question.displayTitle(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(MinukuruTheme.modeAccent(viewModel.question.mode))

                Rectangle()
                    .fill(MinukuruTheme.modeAccent(viewModel.question.mode).opacity(0.22))
                    .frame(width: 72, height: 4)
                    .clipShape(Capsule())
            }

            SegmentFlowLayout(horizontalSpacing: 10, verticalSpacing: 12) {
                ForEach(viewModel.question.segments) { segment in
                    let label = viewModel.selectedSegmentIds.contains(segment.id) ? "選択中" : "未選択"
                    InlineSegmentChip(
                        text: segment.displayText(isHiraganaMode: appViewModel.settings.isHiraganaMode),
                        isSelected: viewModel.selectedSegmentIds.contains(segment.id)
                    ) {
                        viewModel.toggleSegment(segment.id)
                    }
                    .accessibilityLabel("\(segment.displayText(isHiraganaMode: appViewModel.settings.isHiraganaMode))。\(label)")
                }
            }

            Text(appViewModel.settings.isHiraganaMode ? "えらんだかず: \(viewModel.selectedSegmentIds.count)こ" : "選択数: \(viewModel.selectedSegmentIds.count)個")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MinukuruTheme.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MinukuruTheme.modeSoft(viewModel.question.mode).opacity(0.72))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MinukuruTheme.modeAccent(viewModel.question.mode).opacity(0.22), lineWidth: 1.2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct ScamAdStemView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject var viewModel: QuizSessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.question.displayTitle(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(MinukuruTheme.modeAccent(viewModel.question.mode))

                Rectangle()
                    .fill(MinukuruTheme.modeAccent(viewModel.question.mode).opacity(0.22))
                    .frame(width: 72, height: 4)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(viewModel.question.segments.enumerated()), id: \.element.id) { index, segment in
                    let label = viewModel.selectedSegmentIds.contains(segment.id) ? "選択中" : "未選択"
                    ScamAdSegmentCard(
                        text: segment.displayText(isHiraganaMode: appViewModel.settings.isHiraganaMode),
                        isSelected: viewModel.selectedSegmentIds.contains(segment.id),
                        emphasis: emphasis(for: index, total: viewModel.question.segments.count)
                    ) {
                        viewModel.toggleSegment(segment.id)
                    }
                    .accessibilityLabel("\(segment.displayText(isHiraganaMode: appViewModel.settings.isHiraganaMode))。\(label)")
                }
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: [Color.white, MinukuruTheme.accentSoft.opacity(0.65)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(MinukuruTheme.stroke, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            Text(appViewModel.settings.isHiraganaMode ? "えらんだかず: \(viewModel.selectedSegmentIds.count)こ" : "選択数: \(viewModel.selectedSegmentIds.count)個")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MinukuruTheme.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MinukuruTheme.modeSoft(viewModel.question.mode).opacity(0.72))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MinukuruTheme.modeAccent(viewModel.question.mode).opacity(0.22), lineWidth: 1.2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func emphasis(for index: Int, total: Int) -> ScamAdSegmentCard.Emphasis {
        if index == 0 {
            return .badge
        }
        if index == total - 1 {
            return .cta
        }
        if index == 1 {
            return .headline
        }
        return .body
    }
}
