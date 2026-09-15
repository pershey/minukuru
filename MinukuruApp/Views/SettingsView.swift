import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button(appViewModel.settings.isHiraganaMode ? "もどる" : "戻る") {
                    appViewModel.goHome()
                }
                .font(.headline.bold())
                .frame(minHeight: 44)
                .foregroundStyle(MinukuruTheme.primary)

                Text(appViewModel.settings.isHiraganaMode ? "せってい" : "設定")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(MinukuruTheme.primary)

                readingSection
                premiumSection
                contentSection
                noticeSection
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    private var readingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appViewModel.settings.isHiraganaMode ? "よみやすさ" : "読みやすさ")
                .font(.title2.weight(.bold))
                .foregroundStyle(MinukuruTheme.primary)

            Toggle(isOn: Binding(
                get: { appViewModel.settings.isHiraganaMode },
                set: { appViewModel.updateHiraganaMode($0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ひらがなモード")
                        .font(.title3.weight(.semibold))
                    Text(appViewModel.settings.isHiraganaMode
                         ? "ひょうじぶんを ひらがな よりに して、よみやすく します。"
                         : "表示文をひらがな寄りにして、読みやすくします。")
                        .font(.body)
                        .foregroundStyle(MinukuruTheme.muted)
                }
            }
            .toggleStyle(.switch)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var premiumSection: some View {
        PremiumPlanCard(automaticRefreshPasses: 3)
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(appViewModel.settings.isHiraganaMode ? "もんだいの はいしん" : "問題の配信")
                .font(.title2.weight(.bold))
                .foregroundStyle(MinukuruTheme.primary)

            VStack(alignment: .leading, spacing: 8) {
                statusLine(
                    title: appViewModel.settings.isHiraganaMode ? "いま あそべる もんだい" : "いま遊べる問題",
                    value: "\(appViewModel.totalQuestionCount)問"
                )
                statusLine(
                    title: appViewModel.settings.isHiraganaMode ? "よみこみずみの もんだい" : "読み込み済みの問題",
                    value: "\(appViewModel.loadedQuestionCount)問"
                )
                statusLine(
                    title: appViewModel.settings.isHiraganaMode ? "プレミアムの もんだい" : "プレミアムの問題",
                    value: "\(appViewModel.loadedPremiumQuestionCount)問"
                )
                statusLine(
                    title: appViewModel.settings.isHiraganaMode ? "げんじつモードの もんだい" : "現実モードの問題",
                    value: "\(appViewModel.loadedRealWorldQuestionCount)問"
                )

                if let contentStatus = appViewModel.contentStatus {
                    statusLine(
                        title: appViewModel.settings.isHiraganaMode ? "むりょうフィード" : "無料フィード",
                        value: contentStatus.baseContentVersion
                    )

                    if let premiumVersion = contentStatus.premiumContentVersion {
                        statusLine(
                            title: appViewModel.settings.isHiraganaMode ? "プレミアムフィード" : "プレミアムフィード",
                            value: premiumVersion
                        )
                    }
                }
            }

            Button {
                Task {
                    await appViewModel.manuallyRefreshQuestionContent()
                }
            } label: {
                HStack {
                    if appViewModel.isRefreshingContent {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    Text(appViewModel.settings.isHiraganaMode ? "もんだいを こうしん" : "問題を更新")
                        .font(.title3.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(MinukuruTheme.primary)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .disabled(appViewModel.isRefreshingContent)

            if let contentRefreshMessage = appViewModel.contentRefreshMessage {
                Text(contentRefreshMessage)
                    .font(.footnote)
                    .foregroundStyle(MinukuruTheme.muted)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var noticeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(appViewModel.settings.isHiraganaMode ? "おしらせ" : "おしらせ")
                .font(.title2.weight(.bold))
                .foregroundStyle(MinukuruTheme.primary)
            Text(appViewModel.settings.isHiraganaMode
                 ? "たいおうした もんだいは、もんだいぶんや せつめいも ひらがな よりに ひょうじします。"
                 : "対応した問題は、問題文や解説もひらがな寄りに表示します。")
                .font(.body)
                .foregroundStyle(MinukuruTheme.muted)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func statusLine(title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                statusTitle(title)
                Spacer()
                statusValue(value, alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 4) {
                statusTitle(title)
                statusValue(value, alignment: .leading)
            }
        }
    }

    private func statusTitle(_ title: String) -> some View {
        Text(title)
            .font(.body.weight(.semibold))
            .foregroundStyle(MinukuruTheme.primary)
    }

    private func statusValue(_ value: String, alignment: TextAlignment) -> some View {
        Text(value)
            .font(.body)
            .foregroundStyle(MinukuruTheme.muted)
            .multilineTextAlignment(alignment)
    }
}
