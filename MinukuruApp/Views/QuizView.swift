import SwiftUI

struct QuizView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject var viewModel: QuizSessionViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button("モード選択へ") {
                        appViewModel.showModes()
                    }
                    .font(.headline.bold())
                    .foregroundStyle(MinukuruTheme.primary)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.question.mode.title)
                        .font(.headline)
                        .foregroundStyle(MinukuruTheme.primary)
                    Text(viewModel.question.title)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text(viewModel.selectionGuide)
                        .font(.title3)
                        .foregroundStyle(.primary)
                    Text("問題文の中で、気になる言い方や言い切りを押して選んでね。")
                        .font(.body)
                        .foregroundStyle(MinukuruTheme.muted)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MinukuruTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(alignment: .leading, spacing: 14) {
                    Text("問題文")
                        .font(.title2.weight(.bold))
                    QuestionStemCard(viewModel: viewModel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text("全文")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MinukuruTheme.primary)
                    Text(viewModel.questionBodyText)
                        .font(.body)
                        .foregroundStyle(MinukuruTheme.muted)
                        .lineSpacing(4)
                }
                .padding(20)
                .background(MinukuruTheme.panel)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(MinukuruTheme.stroke.opacity(0.8), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 14) {
                    Text("理由タグ")
                        .font(.title2.weight(.bold))
                    Text("どうして怪しいと思ったか、近いものを選んでね。")
                        .font(.body)
                        .foregroundStyle(MinukuruTheme.muted)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                        ForEach(viewModel.recommendedTags) { tag in
                            ReasonTagChip(title: tag.label, isSelected: viewModel.selectedReasonTags.contains(tag)) {
                                viewModel.toggleTag(tag)
                            }
                            .accessibilityLabel(tag.label)
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
                        Label("ヒント", systemImage: "lightbulb.fill")
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
                        Label("答え合わせ", systemImage: "checkmark.seal.fill")
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
            }
            .padding(20)
        }
        .alert("ヒント", isPresented: $viewModel.isHintPresented) {
            Button("とじる", role: .cancel) { }
        } message: {
            Text(viewModel.question.hint)
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
    @ObservedObject var viewModel: QuizSessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("下の文の中から、あやしい部分を押して選ぼう。")
                .font(.headline)
                .foregroundStyle(MinukuruTheme.muted)

            SegmentFlowLayout(horizontalSpacing: 10, verticalSpacing: 12) {
                ForEach(viewModel.question.segments) { segment in
                    let label = viewModel.selectedSegmentIds.contains(segment.id) ? "選択中" : "未選択"
                    InlineSegmentChip(
                        text: segment.text,
                        isSelected: viewModel.selectedSegmentIds.contains(segment.id)
                    ) {
                        viewModel.toggleSegment(segment.id)
                    }
                    .accessibilityLabel("\(segment.text)。\(label)")
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.92))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MinukuruTheme.stroke.opacity(0.9), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct ScamAdStemView: View {
    @ObservedObject var viewModel: QuizSessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("広告っぽい見せ方の中で、気になる言葉を選ぼう。")
                .font(.headline)
                .foregroundStyle(MinukuruTheme.muted)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(viewModel.question.segments.enumerated()), id: \.element.id) { index, segment in
                    let label = viewModel.selectedSegmentIds.contains(segment.id) ? "選択中" : "未選択"
                    ScamAdSegmentCard(
                        text: segment.text,
                        isSelected: viewModel.selectedSegmentIds.contains(segment.id),
                        emphasis: emphasis(for: index, total: viewModel.question.segments.count)
                    ) {
                        viewModel.toggleSegment(segment.id)
                    }
                    .accessibilityLabel("\(segment.text)。\(label)")
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
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.92))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MinukuruTheme.stroke.opacity(0.9), lineWidth: 1)
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
