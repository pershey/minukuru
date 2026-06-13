import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var isShowingResetConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button("ホームへ") {
                    appViewModel.goHome()
                }
                .font(.headline.bold())
                .foregroundStyle(MinukuruTheme.primary)

                Text("成績を見る")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))

                VStack(alignment: .leading, spacing: 16) {
                    StatRow(title: "今日の挑戦数", value: "\(appViewModel.todayChallengeCount)回")
                    StatRow(title: "正解数", value: "\(appViewModel.stats.correctAnswers)回")
                    StatRow(title: "正答率", value: appViewModel.accuracyText)
                    StatRow(title: "連続正解数", value: "\(appViewModel.stats.currentStreak)回")
                    StatRow(title: "ベスト連続", value: "\(appViewModel.stats.bestStreak)回")
                    StatRow(title: "完全正解数", value: "\(appViewModel.stats.perfectAnswers)回")
                    StatRow(title: "見抜きレベル", value: appViewModel.levelTitle)
                    StatRow(title: "合計ポイント", value: "\(appViewModel.stats.totalScore)pt")
                }
                .padding(22)
                .background(MinukuruTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("獲得バッジ")
                        .font(.title2.weight(.bold))
                    ForEach(appViewModel.badgeTitles, id: \.self) { badge in
                        Label(badge, systemImage: "crown.fill")
                            .font(.title3.weight(.semibold))
                            .padding(.vertical, 8)
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.84))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("モードごとの進みぐあい")
                        .font(.title2.weight(.bold))
                    ForEach(appViewModel.modeProgressSummaries) { summary in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(summary.mode.title)
                                    .font(.title3.weight(.semibold))
                                Text("\(summary.progressText) ・ 完全正解 \(summary.perfectCount)回")
                                    .font(.body)
                                    .foregroundStyle(MinukuruTheme.muted)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.84))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("最近の挑戦")
                        .font(.title2.weight(.bold))
                    if appViewModel.recentResults.isEmpty {
                        Text("まだ挑戦の記録はありません。")
                            .font(.title3)
                    } else {
                        ForEach(appViewModel.recentResults) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .font(.title3.weight(.semibold))
                                Text("\(result.modeTitle) ・ \(result.score)pt\(result.wasPerfect ? " ・ 完全正解" : "")")
                                    .font(.body)
                                    .foregroundStyle(MinukuruTheme.muted)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.84))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("理由タグの見方")
                        .font(.title2.weight(.bold))

                    if let strongest = appViewModel.strongestReasoningSummary {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("得意な見方")
                                .font(.headline)
                                .foregroundStyle(MinukuruTheme.primary)
                            Text("\(strongest.tag.label) ・ 当たりやすさ \(strongest.accuracyText)")
                                .font(.title3.weight(.semibold))
                            Text("\(strongest.matchedCount)/\(strongest.selectedCount)回で、この見方が問題のポイントと重なっていました。")
                                .font(.body)
                                .foregroundStyle(MinukuruTheme.muted)
                        }
                    }

                    if let focus = appViewModel.recommendedFocusSummary {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("次に意識したい見方")
                                .font(.headline)
                                .foregroundStyle(MinukuruTheme.primary)
                            Text("\(focus.tag.label) ・ 今は \(focus.accuracyText)")
                                .font(.title3.weight(.semibold))
                            Text("問題ごとの解説と見比べながら、このタグを使う場面を少しずつ増やしていこう。")
                                .font(.body)
                                .foregroundStyle(MinukuruTheme.muted)
                        }
                    }

                    if appViewModel.reasonTagSummaries.isEmpty {
                        Text("まだ理由タグの記録はありません。気になったタグを押すと、見方のくせが見えてきます。")
                            .font(.title3)
                    } else {
                        ForEach(appViewModel.reasonTagSummaries.prefix(4)) { summary in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(summary.tag.label)
                                        .font(.title3.weight(.semibold))
                                    Text("選んだ回数 \(summary.selectedCount)回 ・ 当たりやすさ \(summary.accuracyText)")
                                        .font(.body)
                                        .foregroundStyle(MinukuruTheme.muted)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.84))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                Button(role: .destructive) {
                    isShowingResetConfirmation = true
                } label: {
                    Label("成績をリセット", systemImage: "trash")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(Color.red.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(20)
        }
        .alert("成績をリセットする？", isPresented: $isShowingResetConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("リセット", role: .destructive) {
                appViewModel.resetStats()
            }
        } message: {
            Text("今までの挑戦記録とポイントが消えます。")
        }
    }
}

private struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(MinukuruTheme.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }
}
