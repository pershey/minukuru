import SwiftUI

struct ModeSelectView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var showsAllModes = false

    private let cards: [ModeCard] = [
        ModeCard(mode: .explanationSnipe, difficulty: .easy),
        ModeCard(mode: .newsPoison, difficulty: .normal),
        ModeCard(mode: .scamAdChecker, difficulty: .normal),
        ModeCard(mode: .profileHunter, difficulty: .normal),
        ModeCard(mode: .conspiracyTrap, difficulty: .hard)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                topBar

                VStack(alignment: .leading, spacing: 8) {
                    Text(appViewModel.settings.isHiraganaMode ? "れんしゅうを はじめる" : "練習をはじめる")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(MinukuruTheme.primary)
                        .accessibilityAddTraits(.isHeader)
                    Text(appViewModel.settings.isHiraganaMode
                         ? "まずは おすすめから。テーマも えらべます。"
                         : "まずはおすすめから。テーマを選ぶこともできます。")
                        .font(.body)
                        .foregroundStyle(MinukuruTheme.muted)
                }

                if appViewModel.hasResumableSession {
                    Button {
                        appViewModel.resumePractice()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(appViewModel.settings.isHiraganaMode ? "つづきから" : "続きから", systemImage: "arrow.clockwise.circle.fill")
                                .font(.title2.weight(.bold))
                            if let title = appViewModel.resumableQuestionTitle {
                                Text(title)
                                    .font(.body)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                        .padding(.horizontal, 18)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(MinukuruTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityHint("中断した問題と手順を再開します")
                }

                Button {
                    appViewModel.startPractice()
                } label: {
                    Label(
                        appViewModel.settings.isHiraganaMode ? "おすすめの れんしゅう" : "おすすめの練習",
                        systemImage: "play.fill"
                    )
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 60)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(MinukuruTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityHint("お手本から順に練習を始めます")

                DisclosureGroup(isExpanded: $showsAllModes) {
                    VStack(spacing: 14) {
                        ForEach(cards) { card in
                            modeCard(card)
                        }
                    }
                    .padding(.top, 14)
                } label: {
                    Text(appViewModel.settings.isHiraganaMode ? "テーマから えらぶ" : "テーマから選ぶ")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MinukuruTheme.primary)
                        .frame(minHeight: 48)
                }
                .tint(MinukuruTheme.primary)
                .padding(18)
                .background(Color.white.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                if !appViewModel.hasPremiumAccess {
                    BannerAdView()
                        .accessibilityLabel("広告")
                }
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    private var topBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                titleButton
                Spacer()
                destinationButtons
            }

            VStack(alignment: .leading, spacing: 8) {
                titleButton
                destinationButtons
            }
        }
        .font(.headline.weight(.bold))
        .foregroundStyle(MinukuruTheme.primary)
    }

    private var titleButton: some View {
        Button {
            appViewModel.goHome()
        } label: {
            Label("タイトルへ", systemImage: "chevron.left")
                .frame(minHeight: 44)
        }
    }

    private var destinationButtons: some View {
        HStack(spacing: 16) {
            Button("プレミアム") {
                appViewModel.showPremium(from: .modeSelect)
            }
            .frame(minHeight: 44)

            Button(appViewModel.settings.isHiraganaMode ? "せいせき" : "成績") {
                appViewModel.showStats()
            }
            .frame(minHeight: 44)
        }
    }

    private func modeCard(_ card: ModeCard) -> some View {
        Button {
            appViewModel.startQuiz(for: card.mode)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: card.mode.icon)
                    .font(.title2.weight(.bold))
                    .frame(width: 50, height: 50)
                    .background(MinukuruTheme.modeSoft(card.mode))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(MinukuruTheme.modeAccent(card.mode))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(card.mode.displayTitle(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.leading)
                    Text(card.mode.displayShortDescription(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                        .font(.body)
                        .foregroundStyle(MinukuruTheme.muted)
                        .multilineTextAlignment(.leading)
                    Text("\(appViewModel.answeredCount(for: card.mode))/\(appViewModel.questions(for: card.mode).count)問")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(MinukuruTheme.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .background(MinukuruTheme.background)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(MinukuruTheme.modeAccent(card.mode).opacity(0.24), lineWidth: 1.2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(card.mode.displayTitle(isHiraganaMode: appViewModel.settings.isHiraganaMode))。\(card.mode.displayShortDescription(isHiraganaMode: appViewModel.settings.isHiraganaMode))")
    }
}
