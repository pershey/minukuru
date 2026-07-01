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
                    .foregroundStyle(MinukuruTheme.primary)

                readingSection
                contentSection
                premiumSection
                noticeSection
            }
            .padding(20)
        }
        .task {
            if appViewModel.purchaseManager.premiumProduct == nil {
                await appViewModel.purchaseManager.reloadStoreState()
            }
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(appViewModel.settings.isHiraganaMode ? "プレミアム" : "プレミアム")
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

                Button(appViewModel.settings.isHiraganaMode ? "こうにゅうを ふくげん" : "購入を復元") {
                    Task {
                        await appViewModel.purchaseManager.restorePurchases()
                    }
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(MinukuruTheme.primary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(appViewModel.settings.isHiraganaMode
                         ? "しょうひんじょうほうを かくにんしています。"
                         : "商品情報を確認しています。")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MinukuruTheme.primary)

                    Text(appViewModel.settings.isHiraganaMode
                         ? "TestFlight では、App Store Connect の しょうひんが はんえいされるまで じかんが かかることが あります。"
                         : "TestFlight では、App Store Connect の商品が反映されるまで時間がかかることがあります。")
                        .font(.footnote)
                        .foregroundStyle(MinukuruTheme.muted)

                    Button(appViewModel.settings.isHiraganaMode ? "しょうひんを もういちど よみこむ" : "商品をもう一度読み込む") {
                        Task {
                            await appViewModel.purchaseManager.reloadStoreState()
                        }
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MinukuruTheme.primary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                statusLine(
                    title: appViewModel.settings.isHiraganaMode ? "しょうひんの じょうたい" : "商品の状態",
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
                    .font(.footnote)
                    .foregroundStyle(MinukuruTheme.muted)
            }

            if let purchaseMessage = appViewModel.purchaseManager.purchaseMessage {
                Text(purchaseMessage)
                    .font(.footnote)
                    .foregroundStyle(MinukuruTheme.muted)
            }

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

            if appViewModel.purchaseManager.premiumProduct == nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appViewModel.settings.isHiraganaMode ? "みる ところ" : "見るところ")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MinukuruTheme.primary)
                    Text(appViewModel.settings.isHiraganaMode
                         ? "App Store Connect で しょうひんID、ねだん、りようできる くに、Paid Apps Agreement を かくにんしてください。"
                         : "App Store Connect で商品 ID、価格、利用できる国、Paid Apps Agreement を確認してください。")
                        .font(.footnote)
                        .foregroundStyle(MinukuruTheme.muted)
                    Text(appViewModel.settings.isHiraganaMode
                         ? "はじめての かきんしょうひんは、アプリばんと いっしょに しんさへ だしていないと TestFlight で でないことが あります。"
                         : "初回の課金商品は、アプリ版と一緒に審査へ出していないと TestFlight で出ないことがあります。")
                        .font(.footnote)
                        .foregroundStyle(MinukuruTheme.muted)
                }
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
                .foregroundStyle(MinukuruTheme.primary)
            Text(detail)
                .font(.body)
                .foregroundStyle(MinukuruTheme.muted)
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
