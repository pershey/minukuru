# Minukuru セキュリティ / プライバシー確認メモ

レビュー日: 2026-07-01

## Findings

### 1. 修正済み: Edge Function が内部エラー詳細をそのまま返していた

- 対象: [supabase/functions/content-manifest/index.ts](/Users/naoyaochiai/minukuru/supabase/functions/content-manifest/index.ts)
- 重要度: 中
- 内容:
  - 失敗時に `details: ${error}` をそのままレスポンスに含めていたため、バックエンド構成や SQL/Storage の詳細がクライアントに漏れる可能性がありました。
- 対応:
  - クライアント向けレスポンスから詳細文字列を除去し、サーバーログにだけ `console.error` する形へ変更済みです。

## 追加レビュー結果

高 severity の脆弱性は、今回見た範囲では見つかっていません。

## 残るリスク / 注意点

### A. App Privacy / 広告 SDK 側の申告は慎重にやるべき

- `GoogleMobileAds.framework` の privacy manifest では、`Device ID` が `Tracking = true` と宣言されています。
- これはアプリのコード上の脆弱性ではありませんが、App Store 提出では重要なプライバシー / コンプライアンス論点です。
- 参照:
  - ビルド済み framework の `PrivacyInfo.xcprivacy`

### B. リモート問題配信は HTTPS 前提で信頼している

- 対象:
  - [MinukuruApp/Resources/content_config.json](/Users/naoyaochiai/minukuru/MinukuruApp/Resources/content_config.json)
  - [MinukuruApp/SampleData/QuizRepository.swift](/Users/naoyaochiai/minukuru/MinukuruApp/SampleData/QuizRepository.swift)
- 内容:
  - アプリは Supabase から配信された問題 JSON をそのまま取り込みます。
  - 現状でも HTTPS と公開範囲制御はありますが、ローカル署名検証まではしていません。
- 評価:
  - 扱うのが個人情報ではなく、教育用問題データなのでリスクは中低程度です。
  - ただし、将来ユーザー投稿問題や現実寄り問題を増やすなら、配信前審査と署名・検証の検討余地があります。

### C. ローカル保存データは暗号化していない

- 対象:
  - [MinukuruApp/Storage/StatsStore.swift](/Users/naoyaochiai/minukuru/MinukuruApp/Storage/StatsStore.swift)
  - [MinukuruApp/Storage/AppSettingsStore.swift](/Users/naoyaochiai/minukuru/MinukuruApp/Storage/AppSettingsStore.swift)
  - [MinukuruApp/Storage/QuizContentStore.swift](/Users/naoyaochiai/minukuru/MinukuruApp/Storage/QuizContentStore.swift)
- 内容:
  - 成績、設定、キャッシュ済み問題は UserDefaults / Application Support に保存されています。
- 評価:
  - 名前、連絡先、決済情報などの高機微データは持たないため、現状のままでも実用上は許容範囲です。
  - ただし「学習履歴を他端末同期する」などに進むなら、保存ポリシーの見直しが必要です。

## 結論

- 重大なセキュリティ事故につながる穴は、今回見た範囲ではありません。
- ただし、提出前に本当に大事なのは `App Privacy` と `広告 SDK の扱い` の整合です。
- 「個人情報を持たないから何も気にしなくてよい」までは言えず、広告 SDK とリモート配信があるので、プライバシー申告はちゃんと合わせた方が安全です。
