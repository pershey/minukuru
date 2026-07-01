# Minukuru

SwiftUI で作った、情報リテラシー訓練ゲームアプリです。

## 概要

- アプリ名: ミヌクル
- 対象: 子ども、ネット情報に不慣れな大人、高齢者
- 構成: SwiftUI + MVVM
- データ: ローカル JSON + Supabase リモート配信
- 課金: StoreKit 2
- 広告: Google Mobile Ads

## コンテンツ配信

アプリはローカル問題だけで閉じず、Supabase の manifest を取りにいける構成です。

- `free`
  - 無料版の基本問題
- `premium`
  - premium 購入後に追加取得する差分問題
- `full`
  - 旧互換 / 管理確認用の統合 feed

そのため製品版でも、問題数をアプリ更新なしで増やせます。

## 実装メモ

- iOS 17 以上
- リモート配信設定: [content_config.json](/Users/naoyaochiai/minukuru/MinukuruApp/Resources/content_config.json)
- ローカル問題データ: [questions.json](/Users/naoyaochiai/minukuru/MinukuruApp/Resources/questions.json)
- プロジェクト生成: `xcodegen generate`

## 運用メモ

- Supabase deploy: [DEPLOY_SUPABASE.md](/Users/naoyaochiai/minukuru/DEPLOY_SUPABASE.md)
- Supabase 設計: [SUPABASE_SETUP.md](/Users/naoyaochiai/minukuru/SUPABASE_SETUP.md)
- 問題量産: [CONTENT_FACTORY.md](/Users/naoyaochiai/minukuru/CONTENT_FACTORY.md)
- 配信設計: [CONTENT_OPERATIONS.md](/Users/naoyaochiai/minukuru/CONTENT_OPERATIONS.md)
- 課金 / 広告: [MONETIZATION_SETUP.md](/Users/naoyaochiai/minukuru/MONETIZATION_SETUP.md)
- GitHub 運用: [GITHUB_SETUP.md](/Users/naoyaochiai/minukuru/GITHUB_SETUP.md)

## ビルド

```bash
xcodegen generate
xcodebuild -project Minukuru.xcodeproj -scheme Minukuru -destination 'platform=iOS Simulator,name=iPhone 17' build
```
