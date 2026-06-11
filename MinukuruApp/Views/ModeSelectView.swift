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
                    Button("ホームへ") {
                        appViewModel.goHome()
                    }
                    .font(.headline.bold())
                    .foregroundStyle(MinukuruTheme.primary)

                    Spacer()
                }

                Text("練習モードを選ぶ")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))

                Text("1画面ずつ、ゆっくり見ていけば大丈夫。")
                    .font(.title3)
                    .foregroundStyle(MinukuruTheme.muted)

                VStack(alignment: .leading, spacing: 14) {
                    Text("5つの見方から練習")
                        .font(.title2.weight(.bold))
                    Text("説明文、ニュース風、広告風、プロフィール風、論法のワナを、少しずつ見分けていこう。")
                        .font(.body)
                        .foregroundStyle(MinukuruTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(MinukuruTheme.panel)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(MinukuruTheme.stroke.opacity(0.8), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(spacing: 16) {
                    ForEach(cards) { card in
                        Button {
                            appViewModel.startQuiz(for: card.mode)
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: card.mode.icon)
                                    .font(.system(size: 28, weight: .bold))
                                    .frame(width: 56, height: 56)
                                    .background(MinukuruTheme.panel)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(MinukuruTheme.stroke, lineWidth: 1)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(card.mode.title)
                                        .font(.title3.weight(.bold))
                                        .multilineTextAlignment(.leading)
                                    Text(card.mode.shortDescription)
                                        .font(.body)
                                        .foregroundStyle(MinukuruTheme.muted)
                                        .multilineTextAlignment(.leading)
                                    HStack(spacing: 8) {
                                        Text("難易度 \(card.difficulty.label)")
                                            .font(.subheadline.weight(.bold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(MinukuruTheme.accentSoft)
                                            .clipShape(Capsule())
                                        Text("\(appViewModel.answeredCount(for: card.mode))/\(appViewModel.repository.questions(for: card.mode).count)問")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(MinukuruTheme.primary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(MinukuruTheme.primary)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(MinukuruTheme.card)
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(MinukuruTheme.stroke.opacity(0.8), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(card.mode.title)。\(card.mode.shortDescription)。難易度 \(card.difficulty.label)")
                    }
                }
            }
            .padding(20)
        }
    }
}
