import SwiftUI

struct PremiumPlanCard: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let automaticRefreshPasses: Int

    init(automaticRefreshPasses: Int = 3) {
        self.automaticRefreshPasses = automaticRefreshPasses
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("プレミアムプラン")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(MinukuruTheme.primary)
                Spacer()
                Text(appViewModel.hasPremiumAccess ? "利用中" : "購入できます")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(appViewModel.hasPremiumAccess ? .green : MinukuruTheme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((appViewModel.hasPremiumAccess ? Color.green : MinukuruTheme.accentSoft).opacity(0.18))
                    .clipShape(Capsule())
            }

            Text(appViewModel.settings.isHiraganaMode
                 ? "ついかもんだいと べんりな きのうを まとめて つかえる、かいきりタイプです。"
                 : "追加問題と便利な機能をまとめて使える、買い切りタイプです。")
                .font(.body)
                .foregroundStyle(MinukuruTheme.muted)

            if !appViewModel.hasPremiumAccess, appViewModel.purchaseManager.premiumProduct == nil {
                Text(appViewModel.settings.isHiraganaMode
                     ? "じょうほうが とどくまで、アプリが じどうで なんかいか かくにんします。"
                     : "商品情報が届くまで、アプリが自動で何回か確認します。")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(MinukuruTheme.primary)
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

            premiumFeatureRow(
                title: appViewModel.settings.isHiraganaMode ? "すでに やった もんだいを とばす" : "実施済み問題スキップ",
                detail: appViewModel.settings.isHiraganaMode
                    ? "まだ やっていない もんだいを ゆうせんして だします。"
                    : "まだやっていない問題を優先して出します。"
            )

            premiumFeatureRow(
                title: appViewModel.settings.isHiraganaMode ? "げんじつモード" : "現実モード",
                detail: appViewModel.settings.isHiraganaMode
                    ? "じっさいの さぎこうこく などを もとにした、むずかしい もんだいも だします。"
                    : "実際の詐欺広告などをモデルにした、難しい問題も出します。"
            )

            premiumCallToAction

            if appViewModel.hasPremiumAccess {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { appViewModel.settings.isSkipAnsweredEnabled },
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

                    Toggle(isOn: Binding(
                        get: { appViewModel.settings.isRealityModeEnabled },
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
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                statusLine(
                    title: appViewModel.settings.isHiraganaMode ? "プレミアムの じょうたい" : "プレミアムの状態",
                    value: productFetchStateLabel
                )
                statusLine(
                    title: appViewModel.settings.isHiraganaMode ? "かきん せいげん" : "課金制限",
                    value: appViewModel.purchaseManager.canMakePayments
                        ? (appViewModel.settings.isHiraganaMode ? "なし" : "なし")
                        : (appViewModel.settings.isHiraganaMode ? "あり" : "あり")
                )

                if let lastStoreSyncAt = appViewModel.purchaseManager.lastStoreSyncAt {
                    statusLine(
                        title: appViewModel.settings.isHiraganaMode ? "さいごに かくにんした じかん" : "最後に確認した時間",
                        value: Self.storeTimeFormatter.string(from: lastStoreSyncAt)
                    )
                }
            }

            if let productFetchMessage = appViewModel.purchaseManager.productFetchMessage {
                Text(productFetchMessage)
                    .font(.body)
                    .foregroundStyle(MinukuruTheme.muted)
            }

            if let purchaseMessage = appViewModel.purchaseManager.purchaseMessage {
                Text(purchaseMessage)
                    .font(.body)
                    .foregroundStyle(MinukuruTheme.muted)
            }

            #if DEBUG
            if let purchaseDebugDetail = appViewModel.purchaseManager.purchaseDebugDetail {
                Text(purchaseDebugDetail)
                    .font(.footnote)
                    .foregroundStyle(MinukuruTheme.muted)
                    .textSelection(.enabled)
            }

            if !appViewModel.purchaseManager.storeDiagnostics.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appViewModel.settings.isHiraganaMode ? "かくにんよう じょうほう" : "確認用情報")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MinukuruTheme.primary)

                    ForEach(appViewModel.purchaseManager.storeDiagnostics, id: \.self) { line in
                        Text("・\(line)")
                            .font(.footnote)
                            .foregroundStyle(MinukuruTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            #endif
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .task {
            await appViewModel.purchaseManager.ensurePremiumProductAvailable(
                maxRefreshPasses: automaticRefreshPasses
            )
        }
    }

    private func premiumFeatureRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(MinukuruTheme.primary)
            Text(detail)
                .font(.body)
                .foregroundStyle(MinukuruTheme.muted)
        }
    }

    private var premiumCallToAction: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let product = appViewModel.purchaseManager.premiumProduct {
                Button {
                    Task {
                        await appViewModel.purchaseManager.purchasePremium()
                    }
                } label: {
                    HStack(spacing: 10) {
                        if appViewModel.purchaseManager.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        }
                        Text(appViewModel.hasPremiumAccess
                             ? (appViewModel.settings.isHiraganaMode ? "プレミアム りようちゅう" : "プレミアム利用中")
                             : "\(product.displayPrice)で解放")
                            .font(.title3.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(appViewModel.hasPremiumAccess ? Color.green : MinukuruTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .disabled(appViewModel.hasPremiumAccess || appViewModel.purchaseManager.isLoading)
            } else if appViewModel.purchaseManager.productFetchState == .loading {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(MinukuruTheme.primary)
                    Text(appViewModel.settings.isHiraganaMode ? "プレミアムじょうほうを よみこんでいます。" : "プレミアム情報を読み込んでいます。")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MinukuruTheme.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .background(MinukuruTheme.accentSoft.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                Button(appViewModel.settings.isHiraganaMode ? "プレミアムじょうほうを よみこむ" : "プレミアム情報を読み込む") {
                    Task {
                        await appViewModel.purchaseManager.ensurePremiumProductAvailable(
                            maxRefreshPasses: automaticRefreshPasses
                        )
                    }
                }
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(MinukuruTheme.primary)
                .background(MinukuruTheme.accentSoft.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            Button(appViewModel.settings.isHiraganaMode ? "こうにゅうを ふくげん" : "購入を復元") {
                Task {
                    await appViewModel.purchaseManager.restorePurchases()
                }
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(MinukuruTheme.primary)
        }
    }

    private func statusLine(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(MinukuruTheme.primary)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundStyle(MinukuruTheme.muted)
                .multilineTextAlignment(.trailing)
        }
    }

    private var productFetchStateLabel: String {
        switch appViewModel.purchaseManager.productFetchState {
        case .idle:
            return appViewModel.settings.isHiraganaMode ? "みかくにん" : "未確認"
        case .loading:
            return appViewModel.settings.isHiraganaMode ? "よみこみちゅう" : "読み込み中"
        case .loaded:
            return appViewModel.settings.isHiraganaMode ? "しゅとく できた" : "取得できた"
        case .unavailable:
            return appViewModel.settings.isHiraganaMode ? "みつからない" : "見つからない"
        case .failed:
            return appViewModel.settings.isHiraganaMode ? "しっぱい" : "失敗"
        }
    }

    private static let storeTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
