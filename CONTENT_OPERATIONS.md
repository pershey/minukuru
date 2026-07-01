# Minukuru Content Operations

## いまの配信方式

- アプリはまず bundled の [questions.json](/Users/naoyaochiai/minukuru/MinukuruApp/Resources/questions.json) を読みます
- 端末にキャッシュ済み manifest があれば、そちらを優先します
- [content_config.json](/Users/naoyaochiai/minukuru/MinukuruApp/Resources/content_config.json) に配信先 URL が入っている場合だけ、裏でリモート更新を取りにいきます
- 通常起動時は `free` feed を取得します
- プレミアム購入後は `premium` feed を強制再取得して、端末内で `free + premium` をマージします
- 旧互換 / 管理確認用として `full` feed も返せます

実装の入口:

- [QuizRepository.swift](/Users/naoyaochiai/minukuru/MinukuruApp/SampleData/QuizRepository.swift)
- [QuizContentStore.swift](/Users/naoyaochiai/minukuru/MinukuruApp/Storage/QuizContentStore.swift)
- [AppViewModel.swift](/Users/naoyaochiai/minukuru/MinukuruApp/ViewModels/AppViewModel.swift)
- [content_config.json](/Users/naoyaochiai/minukuru/MinukuruApp/Resources/content_config.json)

## 3 つの feed

### `free`

- 無料版用の問題セット
- 今は 50 問を想定
- `remoteFreeQuestionsURL` から取得

### `premium`

- `accessTier: premium` の追加問題だけ
- 購入後にだけ取得
- `remotePremiumQuestionsURL` から取得

### `full`

- `free + premium` をまとめた feed
- legacy クライアントや配信確認用
- `remoteQuestionsURL` から取得

## キャッシュの考え方

アプリは feed ごとに別キャッシュを持ちます。

- `cached-free-questions.json`
- `cached-premium-questions.json`
- `cached-questions.json`

そのため:

- 無料版は `free` だけで起動できる
- 購入後に `premium` だけを差分追加できる
- premium 解約前の再インストールや失効時にも、表示ロジック側で除外しやすい

## `content_config.json` の形

```json
{
  "remoteQuestionsURL": "https://<PROJECT_REF>.supabase.co/functions/v1/content-manifest",
  "remoteFreeQuestionsURL": "https://<PROJECT_REF>.supabase.co/functions/v1/content-manifest?channel=free",
  "remotePremiumQuestionsURL": "https://<PROJECT_REF>.supabase.co/functions/v1/content-manifest?channel=premium",
  "minimumFetchIntervalMinutes": 180,
  "minimumPremiumFetchIntervalMinutes": 15,
  "freeQuestionLimit": 50
}
```

## 配信 JSON の形

manifest 形式を使います。

```json
{
  "schemaVersion": 1,
  "contentVersion": "2026-06-27-openai-premium",
  "updatedAt": "2026-06-27T09:00:00Z",
  "questions": [
    {
      "id": "premium-001",
      "mode": "scamAdChecker",
      "title": "個別案内の告知",
      "difficulty": "hard",
      "instruction": "怪しい表現を選んでください。",
      "segments": [
        { "id": "s1", "text": "限定で少人数に先行案内をしています。" }
      ],
      "correctSegmentIds": ["s1"],
      "explanation": "限定感で急がせています。",
      "verificationTip": "公開情報と照らして確認しましょう。",
      "hint": "限定や秘密の言い方に注目。",
      "recommendedReasonTags": ["urgency"],
      "accessTier": "premium",
      "contentFlavor": "realWorld"
    }
  ]
}
```

## 更新運用の基本フロー

1. 生成・審査して `build-manifest-set` を作る
2. `free_manifest.json` と `premium_manifest.json` と `full_manifest.json` を Storage に upload する
3. `question_manifests` に `distribution_channel` 付きで `staged` 登録する
4. `publish-now` か `pg_cron` で `published` に切り替える
5. アプリは次回 fetch で更新を拾う

## TestFlight で premium 体験を確認する流れ

1. 無料状態で起動する
2. `free` feed がキャッシュされる
3. 課金する
4. `PurchaseManager` の状態変化を `AppViewModel` が受ける
5. `premium` feed を `force: true` で再取得する
6. 端末内で `free + premium` をマージして表示する

このため、製品版でも「ローカルの 50 問だけで終わる」構成ではなく、Supabase 上の manifest を読みにいく運用へ移行できます。

## いま実際に公開している feed

このプロジェクトの Supabase では、すでに次を publish 済みです。

- `free`: `demo-20260627-openai-free`
- `premium`: `demo-20260627-openai-premium`
- `full`: `demo-20260627-openai-full`

## 実運用で追加したいもの

- 運営用 CMS
- 下書き、審査中、公開済みの状態管理 UI
- 危険語チェック
- 問題の停止フラグ
- premium / realWorld の AB テスト

## 注意

- `content_config.json` 自体はアプリに同梱されるので、URL の切り替え用ではなく「固定の公開入口」を持たせる用途です
- 途中で配信先を切り替えたくなるなら、将来は別の設定 endpoint を 1 本かませると安全です
- `premium` feed は必ず `accessTier: premium` だけにして、無料問題を重複させない方が運用しやすいです
