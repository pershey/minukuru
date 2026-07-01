# Minukuru App Privacy 入力ドラフト

これは App Store Connect の `App Privacy` 入力用メモです。

重要:

- これは法務判断ではなく、現在の実装と SDK の privacy manifest を元にした入力ドラフトです
- 特に `Google Mobile Ads` の privacy manifest を優先して記載しています

## 実装ベースの前提

- ローカル保存
  - 成績
  - 回答履歴
  - 設定
- リモート通信
  - Supabase Edge Function / Storage から問題マニフェストを取得
- 広告
  - Google Mobile Ads SDK
- 課金
  - Apple StoreKit 2

## 収集データの考え方

### アプリ自身が直接集める個人情報

- 名前: `収集しない`
- メールアドレス: `収集しない`
- 電話番号: `収集しない`
- 住所: `収集しない`
- 連絡先: `収集しない`
- 写真 / 動画 / 音声: `収集しない`
- 健康 / 財務情報: `収集しない`

### 端末内だけに保存して外部送信しないもの

- 成績
- 回答履歴
- 理由タグの選択
- ひらがなモード設定

これらは App Privacy では通常 `収集` ではなく、端末内保存として扱う想定です。

## Google Mobile Ads の privacy manifest から見える項目

ビルド済み framework の privacy manifest では、少なくとも次が宣言されています。

- Device ID
- Advertising Data
- Product Interaction
- Coarse Location
- Performance Data
- Crash Data
- Other Diagnostic Data

加えて、`Device ID` は `Tracking = true` と宣言されています。

## 入力ドラフト

### Does this app collect data?

- `Yes`

### Is this data linked to the user?

少なくとも広告 SDK 側では、次を `Linked = true` とみなすのが安全です。

- Device ID
- Advertising Data
- Product Interaction
- Coarse Location

### Is this data used for tracking?

少なくとも広告 SDK 側では、`Device ID` が `Tracking = true` と宣言されています。

そのため保守的には:

- `Yes, this app may use data for tracking`

として入力し、実際の広告運用と ATT 方針を合わせるのが安全です。

## 入力候補一覧

### Identifiers

- Device ID
  - Collected: `Yes`
  - Linked to user: `Yes`
  - Used for tracking: `Yes`
  - Purpose:
    - `Third-Party Advertising`
    - `Developer's Advertising or Marketing`
    - `Analytics`

### Usage Data

- Product Interaction
  - Collected: `Yes`
  - Linked to user: `Yes`
  - Used for tracking: `No`
  - Purpose:
    - `Third-Party Advertising`
    - `Developer's Advertising or Marketing`
    - `Analytics`

### Location

- Coarse Location
  - Collected: `Yes`
  - Linked to user: `Yes`
  - Used for tracking: `No`
  - Purpose:
    - `Third-Party Advertising`
    - `Developer's Advertising or Marketing`
    - `Analytics`

### Diagnostics

- Performance Data
  - Collected: `Yes`
  - Linked to user: `No`
  - Used for tracking: `No`
  - Purpose:
    - `Third-Party Advertising`
    - `Developer's Advertising or Marketing`
    - `Analytics`

- Crash Data
  - Collected: `Yes`
  - Linked to user: `No`
  - Used for tracking: `No`
  - Purpose:
    - `Analytics`

- Other Diagnostic Data
  - Collected: `Yes`
  - Linked to user: `No`
  - Used for tracking: `No`
  - Purpose:
    - `Third-Party Advertising`
    - `Developer's Advertising or Marketing`
    - `Analytics`

### Advertising Data

- Advertising Data
  - Collected: `Yes`
  - Linked to user: `Yes`
  - Used for tracking: `No`
  - Purpose:
    - `Third-Party Advertising`
    - `Developer's Advertising or Marketing`
    - `Analytics`

## 補足

- Supabase から取得する問題データは、ユーザーを識別する目的ではなく、コンテンツ配信のためです
- 現状の Swift 実装では、ユーザー名やメールアドレスを送信する処理はありません
- ただし App Privacy は SDK 宣言ベースで見られることがあるため、広告 SDK の manifest に合わせて保守的に入力するのが無難です

## 追加で確認したいこと

- ATT 許諾ダイアログを出すかどうか
- AdMob をパーソナライズド広告運用にするかどうか
- EEA / UK 向けの広告同意フローを入れるかどうか
