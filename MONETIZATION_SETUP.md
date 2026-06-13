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
- 購入後に全問題、スキップ、現実モードが使えるか
- `購入を復元` が動くか

## 4. 今後やるとよいこと

- 実広告表示位置の AB テスト
- ペイウォール文言の調整
- 現実モード問題を Supabase 配信に乗せる
- サーバ側で premium 専用 manifest を分けるかの検討
