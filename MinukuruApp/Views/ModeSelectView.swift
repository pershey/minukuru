import SwiftUI

struct ModeSelectView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

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
                HStack {
                    Button("タイトルへ") {
                        appViewModel.goHome()
                    }
                    .font(.headline.bold())
                    .foregroundStyle(MinukuruTheme.primary)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(appViewModel.settings.isHiraganaMode ? "モードを えらぶ" : "モードをえらぶ")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text(appViewModel.settings.isHiraganaMode ? "きになる テーマから、みぬく れんしゅうを はじめよう。" : "気になるテーマから、見抜く練習をはじめよう。")
                        .font(.body)
                        .foregroundStyle(MinukuruTheme.muted)
                }

                VStack(spacing: 14) {
                    ForEach(cards) { card in
                        Button {
                            appViewModel.startQuiz(for: card.mode)
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: card.mode.icon)
                                    .font(.system(size: 24, weight: .bold))
                                    .frame(width: 52, height: 52)
                                    .background(MinukuruTheme.modeSoft(card.mode))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(MinukuruTheme.modeAccent(card.mode).opacity(0.35), lineWidth: 1)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .foregroundStyle(MinukuruTheme.modeAccent(card.mode))

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(card.mode.displayTitle(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                                        .font(.title3.weight(.bold))
                                        .multilineTextAlignment(.leading)
                                    Text(card.mode.displayShortDescription(isHiraganaMode: appViewModel.settings.isHiraganaMode))
                                        .font(.body)
                                        .foregroundStyle(MinukuruTheme.muted)
                                        .multilineTextAlignment(.leading)
                                    HStack(spacing: 8) {
                                        Text(appViewModel.settings.isHiraganaMode ? "なんいど \(card.difficulty.label)" : "難易度 \(card.difficulty.label)")
                                            .font(.footnote.weight(.bold))
                                            .foregroundStyle(MinukuruTheme.modeAccent(card.mode))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(MinukuruTheme.modeSoft(card.mode))
                                            .clipShape(Capsule())

                                        Text("\(appViewModel.answeredCount(for: card.mode))/\(appViewModel.questions(for: card.mode).count)問")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(MinukuruTheme.muted)
                                    }

                                    if !appViewModel.hasPremiumAccess,
                                       appViewModel.premiumLockedQuestionCount(for: card.mode) > 0 {
                                        Text(appViewModel.settings.isHiraganaMode
                                             ? "プレミアムで \(appViewModel.premiumLockedQuestionCount(for: card.mode))もん ついか"
                                             : "プレミアムで \(appViewModel.premiumLockedQuestionCount(for: card.mode))問追加")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(MinukuruTheme.primary)
                                    }
                                }

                                Spacer()
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.93))
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(MinukuruTheme.modeAccent(card.mode).opacity(0.22), lineWidth: 1.2)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(card.mode.displayTitle(isHiraganaMode: appViewModel.settings.isHiraganaMode))。\(card.mode.displayShortDescription(isHiraganaMode: appViewModel.settings.isHiraganaMode))。\(appViewModel.settings.isHiraganaMode ? "なんいど" : "難易度") \(card.difficulty.label)")
                    }
                }
            }
            .padding(20)
        }
    }
}
