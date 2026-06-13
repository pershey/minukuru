# Minukuru

SwiftUI で作った、情報リテラシー訓練ゲームアプリです。

## 概要

- アプリ名: ミヌクル
- サブタイトル: 嘘・詐欺・フェイクを見抜く練習
- 対象: 子ども、ネット情報に不慣れな大人、高齢者
- 構成: SwiftUI + MVVM
- データ: ローカル JSON + 将来のリモート配信土台あり

## 開発メモ

- iOS 17 以上
- 外部ライブラリなし
- 問題データは `MinukuruApp/Resources/questions.json`
- リモート配信設定は `MinukuruApp/Resources/content_config.json`
- プロジェクト生成は `xcodegen generate`

## 運用メモ

- Supabase deploy 手順: [`DEPLOY_SUPABASE.md`](/Users/naoyaochiai/minukuru/DEPLOY_SUPABASE.md)
- GitHub 運用メモ: [`GITHUB_SETUP.md`](/Users/naoyaochiai/minukuru/GITHUB_SETUP.md)

## ビルド

```bash
xcodegen generate
xcodebuild -project Minukuru.xcodeproj -scheme Minukuru -destination 'generic/platform=iOS Simulator' build
```
