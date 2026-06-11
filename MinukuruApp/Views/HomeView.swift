import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 24)

                VStack(spacing: 20) {
                    SignalCrest()

                    Text("ミヌクル")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(MinukuruTheme.primary)

                    Text("嘘・詐欺・フェイクを見抜く練習")
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)

                    Text("あやしい情報をコンコン見抜こう")
                        .font(.title3.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(MinukuruTheme.muted)
                }
                .padding(28)
                .frame(maxWidth: .infinity)
                .background(MinukuruTheme.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(MinukuruTheme.stroke, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Text("ゆっくり見抜く")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(MinukuruTheme.accentSoft)
                        .clipShape(Capsule())
                        .offset(x: -16, y: 16)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Label("あやしいところを見つけよう", systemImage: "magnifyingglass.circle.fill")
                    Label("だまされない力を育てよう", systemImage: "shield.lefthalf.filled")
                    Label("ほんとうかどうか、たしかめよう", systemImage: "book.closed.fill")
                }
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .background(MinukuruTheme.panel)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(MinukuruTheme.stroke.opacity(0.8), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(spacing: 14) {
                    PrimaryButton(title: "はじめる", systemImage: "play.fill") {
                        appViewModel.showModes()
                    }
                    .accessibilityLabel("はじめる")

                    SecondaryButton(title: "練習モードを選ぶ", systemImage: "square.grid.2x2.fill") {
                        appViewModel.showModes()
                    }
                    .accessibilityLabel("練習モードを選ぶ")

                    SecondaryButton(title: "成績を見る", systemImage: "chart.bar.fill") {
                        appViewModel.showStats()
                    }
                    .accessibilityLabel("成績を見る")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("きょうのようす")
                        .font(.title2.weight(.bold))
                    Label("見抜きレベル: \(appViewModel.levelTitle)", systemImage: "crown.fill")
                    Label("入っている問題: 全\(appViewModel.totalQuestionCount)問", systemImage: "shippingbox.fill")
                    Label("今日の挑戦: \(appViewModel.todayChallengeCount)回", systemImage: "calendar")
                }
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .background(MinukuruTheme.panel)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(MinukuruTheme.stroke.opacity(0.8), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct SignalCrest: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, MinukuruTheme.accentSoft.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 150, height: 110)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(MinukuruTheme.stroke, lineWidth: 1)
                }

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(MinukuruTheme.primary.opacity(0.18), lineWidth: 8)
                        .frame(width: 54, height: 54)
                    Circle()
                        .stroke(MinukuruTheme.primary, lineWidth: 4)
                        .frame(width: 34, height: 34)
                    Circle()
                        .fill(MinukuruTheme.accent)
                        .frame(width: 10, height: 10)
                }

                HStack(spacing: 8) {
                    Capsule()
                        .fill(MinukuruTheme.primary.opacity(0.24))
                        .frame(width: 36, height: 6)
                    Capsule()
                        .fill(MinukuruTheme.primary)
                        .frame(width: 48, height: 6)
                    Capsule()
                        .fill(MinukuruTheme.primary.opacity(0.24))
                        .frame(width: 24, height: 6)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ミヌクルのシンボル")
    }
}

private struct PrimaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(MinukuruTheme.primary)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle())
    }
}

private struct SecondaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MinukuruTheme.primary)
        .background(MinukuruTheme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle())
    }
}
