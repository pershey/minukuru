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
                .foregroundStyle(MinukuruTheme.primary)

                Text(appViewModel.settings.isHiraganaMode ? "せってい" : "設定")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))

                readingSection
                premiumSection
                noticeSection
            }
            .padding(20)
        }
    }

    private var readingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appViewModel.settings.isHiraganaMode ? "よみやすさ" : "読みやすさ")
                .font(.title2.weight(.bold))

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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(appViewModel.settings.isHiraganaMode ? "プレミアム" : "プレミアム")
                    .font(.title2.weight(.bold))
                Spacer()
                Text(appViewModel.hasPremiumAccess ? "利用中" : "購入できます")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(appViewModel.hasPremiumAccess ? .green : MinukuruTheme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((appViewModel.hasPremiumAccess ? Color.green : MinukuruTheme.accentSoft).opacity(0.18))
                    .clipShape(Capsule())
            }

            premiumFeatureRow(
                title: appViewModel.settings.isHiraganaMode ? "ぜんもんだい かいほう" : "全問題解放",
                detail: appViewModel.settings.isHiraganaMode
                    ? "むりょうばんの 50もん いこうも、ついかされた もんだいを あそべます。"
                    : "無料版の50問以降も、追加された問題を遊べます。"
            )

            premiumFeatureRow(
                title: appViewModel.settings.isHiraganaMode ? "こうこく ひひょうじ" : "広告非表示",
                detail: appViewModel.settings.isHiraganaMode
                    ? "むりょうばんで ひょうじされる こうこくエリアを けします。"
                    : "無料版で表示される広告エリアを消します。"
            )

            Toggle(isOn: Binding(
                get: { appViewModel.hasPremiumAccess && appViewModel.settings.isSkipAnsweredEnabled },
                set: { appViewModel.updateSkipAnsweredMode($0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appViewModel.settings.isHiraganaMode ? "すでに やった もんだいを とばす" : "実施済み問題スキップ")
                        .font(.title3.weight(.semibold))
                    Text(appViewModel.settings.isHiraganaMode
                         ? "まだ やっていない もんだいを ゆうせんして だします。"
                         : "まだやっていない問題を優先して出します。")
                        .font(.body)
                        .foregroundStyle(MinukuruTheme.muted)
                }
            }
            .toggleStyle(.switch)
            .disabled(!appViewModel.hasPremiumAccess)

            Toggle(isOn: Binding(
                get: { appViewModel.hasPremiumAccess && appViewModel.settings.isRealityModeEnabled },
                set: { appViewModel.updateRealityMode($0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appViewModel.settings.isHiraganaMode ? "げんじつモード" : "現実モード")
                        .font(.title3.weight(.semibold))
                    Text(appViewModel.settings.isHiraganaMode
                         ? "じっさいの さぎこうこく などを もとにした、むずかしい もんだいも だします。"
                         : "実際の詐欺広告などをモデルにした、難しい問題も出します。")
                        .font(.body)
                        .foregroundStyle(MinukuruTheme.muted)
                }
            }
            .toggleStyle(.switch)
            .disabled(!appViewModel.hasPremiumAccess)

            if let product = appViewModel.purchaseManager.premiumProduct {
                Button {
                    Task {
                        await appViewModel.purchaseManager.purchasePremium()
                    }
                } label: {
                    Text(appViewModel.hasPremiumAccess
                         ? (appViewModel.settings.isHiraganaMode ? "プレミアム りようちゅう" : "プレミアム利用中")
                         : "\(product.displayPrice)で解放")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(appViewModel.hasPremiumAccess ? Color.green : MinukuruTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .disabled(appViewModel.hasPremiumAccess || appViewModel.purchaseManager.isLoading)

                Button(appViewModel.settings.isHiraganaMode ? "こうにゅうを ふくげん" : "購入を復元") {
                    Task {
                        await appViewModel.purchaseManager.restorePurchases()
                    }
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(MinukuruTheme.primary)
            }

            if let purchaseMessage = appViewModel.purchaseManager.purchaseMessage {
                Text(purchaseMessage)
                    .font(.footnote)
                    .foregroundStyle(MinukuruTheme.muted)
            }

            Text(appViewModel.settings.isHiraganaMode
                 ? "テストでは StoreKit の しょうひんせってい、ほんばんでは App Store Connect の しょうひんが ひつようです。"
                 : "テストではStoreKitの商品設定、本番では App Store Connect の商品登録が必要です。")
                .font(.footnote)
                .foregroundStyle(MinukuruTheme.muted)
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
            Text(appViewModel.settings.isHiraganaMode
                 ? "いまは アプリの ひょうじぶんを ちゅうしんに ひらがな よりに しています。もんだいぶんも、こんご ふりがなつき データに たいおうできます。"
                 : "いまはアプリの表示文を中心に、ひらがな寄りにしています。問題文も今後、ふりがな付きデータに対応できます。")
                .font(.body)
                .foregroundStyle(MinukuruTheme.muted)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func premiumFeatureRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(detail)
                .font(.body)
                .foregroundStyle(MinukuruTheme.muted)
        }
    }
}
