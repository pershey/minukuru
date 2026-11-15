import SwiftUI

struct PremiumView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let origin: AppViewModel.PremiumOrigin

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button(backButtonTitle) {
                    appViewModel.leavePremium(origin)
                }
                .font(.headline.bold())
                .foregroundStyle(MinukuruTheme.primary)

                VStack(alignment: .leading, spacing: 8) {
                    Text(appViewModel.settings.isHiraganaMode ? "プレミアム" : "プレミアム")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(MinukuruTheme.primary)

                    Text(appViewModel.settings.isHiraganaMode
                         ? "ついかの もんだいと べんりな きのうを ひらいて、もっと れんしゅうを つづけられます。"
                         : "追加の問題と便利な機能をひらいて、もっと練習を続けられます。")
                        .font(.body)
                        .foregroundStyle(MinukuruTheme.muted)
                }

                PremiumPlanCard(automaticRefreshPasses: 4)

                if !appViewModel.hasPremiumAccess {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(appViewModel.settings.isHiraganaMode ? "かくにんの しかた" : "確認のしかた")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MinukuruTheme.primary)

                        Text(appViewModel.settings.isHiraganaMode
                             ? "よみこみちゅうの ばあいも、しばらく そのままで まつと じどうで さいど かくにんします。"
                             : "読み込み中の場合も、しばらくそのままで待つと自動で再度確認します。")
                            .font(.body)
                            .foregroundStyle(MinukuruTheme.muted)
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    private var backButtonTitle: String {
        switch origin {
        case .home:
            return appViewModel.settings.isHiraganaMode ? "タイトルへ" : "タイトルへ"
        case .modeSelect:
            return appViewModel.settings.isHiraganaMode ? "モードへ" : "モードへ"
        case .settings:
            return appViewModel.settings.isHiraganaMode ? "せっていへ" : "設定へ"
        }
    }
}
