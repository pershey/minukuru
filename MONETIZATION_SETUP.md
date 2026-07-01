# Minukuru 課金・広告セットアップ

ミヌクルでは次の 2 つを実装済みです。

- `StoreKit 2` によるプレミアム解放
- `Google Mobile Ads SDK` による無料版バナー広告

## 実装場所

- 購入管理: [PurchaseManager.swift](/Users/naoyaochiai/minukuru/MinukuruApp/ViewModels/PurchaseManager.swift)
- 課金/広告 ID: [MonetizationConfig.swift](/Users/naoyaochiai/minukuru/MinukuruApp/Models/MonetizationConfig.swift)
- 広告表示: [BannerAdView.swift](/Users/naoyaochiai/minukuru/MinukuruApp/Views/BannerAdView.swift)
- 設定画面: [SettingsView.swift](/Users/naoyaochiai/minukuru/MinukuruApp/Views/SettingsView.swift)
- Info.plist: [Info.plist](/Users/naoyaochiai/minukuru/MinukuruApp/Resources/Info.plist)

## いまの状態

- 課金商品 ID: `com.naoyaochiai.minukuru.premium`
- AdMob App ID: `ca-app-pub-7844017135115297~6684600489`
- バナー Unit ID: `ca-app-pub-7844017135115297/9721827369`

本番 ID への差し替えは完了しています。

## 1. App Store Connect で課金商品を作る

種別:

- `Non-Consumable`

商品 ID:

- `com.naoyaochiai.minukuru.premium`

この ID は [MonetizationConfig.swift](/Users/naoyaochiai/minukuru/MinukuruApp/Models/MonetizationConfig.swift) とそろえてください。

## 2. AdMob で本番 ID を管理する

差し替える場所:

- [MonetizationConfig.swift](/Users/naoyaochiai/minukuru/MinukuruApp/Models/MonetizationConfig.swift)
  - `admobBannerUnitID`
- [Info.plist](/Users/naoyaochiai/minukuru/MinukuruApp/Resources/Info.plist)
  - `GADApplicationIdentifier`

## 3. TestFlight / 実機確認で見るポイント

- 無料版で広告が表示されるか
- 購入後に広告が消えるか
- 購入後に `premium` feed が再取得され、追加問題が増えるか
- 購入後に全問題、スキップ、現実モードが使えるか
- `購入を復元` が動くか

## 3.5 TestFlight で購入ボタンが出ない / 動かないときの確認

- Paid Apps Agreement が `Active` になっているか
- 銀行口座と税務情報が完了しているか
- 課金商品の status が `Missing Metadata` ではなく、最低でも `Ready to Submit` になっているか
- 価格、スクリーンショット、説明文、販売国が設定済みか
- 初回の課金商品なら、アプリの新しいバージョンに紐づけて一緒に審査へ出しているか
- TestFlight では sandbox で動くため、必要なら Sandbox Apple Account で検証する

Apple 公式:

- [Testing subscriptions and In-App Purchases in TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight)
- [In-App Purchase statuses](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-statuses/)
- [Overview for configuring In-App Purchases](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/)
- [Submit an In-App Purchase](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/)

## 4. 今後やるとよいこと

- 実広告表示位置の AB テスト
- ペイウォール文言の調整
- 現実モード問題を `premium` feed で継続追加する
- `free / premium / full` の publish 頻度を運用に合わせて見直す
