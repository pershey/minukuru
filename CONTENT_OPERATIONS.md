# Minukuru Content Operations

## いまの配信方式

- アプリは起動時にまず bundled の `questions.json` を読みます
- 端末にキャッシュ済みの問題セットがあれば、そちらを優先します
- `content_config.json` に `remoteQuestionsURL` が入っている場合だけ、裏でリモート更新を取りにいきます
- リモート取得に成功すると、次回以降はキャッシュ済みの新しい問題セットを使います

実装の入口:

- `/Users/naoyaochiai/minukuru/MinukuruApp/SampleData/QuizRepository.swift`
- `/Users/naoyaochiai/minukuru/MinukuruApp/Storage/QuizContentStore.swift`
- `/Users/naoyaochiai/minukuru/MinukuruApp/Resources/content_config.json`

## おすすめ構成

### まずは簡単に始める案

1. Supabase Storage か CDN に `questions.json` を置く
2. アプリの `content_config.json` にその URL を入れる
3. 運営は JSON を差し替えるだけで更新する

### もう少し安全にやる案

1. 公開用 URL は `quiz-manifest.json` など固定にする
2. 更新前にステージング URL で確認する
3. 運営レビュー後に本番 URL の JSON を入れ替える

## リモート JSON の形

アプリは次の 2 形式を読めます。

### 1. 既存の配列形式

```json
[
  {
    "id": "exp-001",
    "mode": "explanationSnipe",
    "title": "サンプル",
    "difficulty": "easy",
    "instruction": "あやしいところを見つけよう",
    "segments": [
      { "id": "s1", "text": "本文です。" }
    ],
    "correctSegmentIds": ["s1"],
    "explanation": "解説",
    "verificationTip": "確認のしかた",
    "hint": "ヒント",
    "recommendedReasonTags": ["gutFeeling"]
  }
]
```

### 2. バージョン付き manifest 形式

```json
{
  "schemaVersion": 1,
  "contentVersion": "2026-06-13-a",
  "updatedAt": "2026-06-13T08:00:00Z",
  "questions": [
    {
      "id": "exp-001",
      "mode": "explanationSnipe",
      "title": "サンプル",
      "difficulty": "easy",
      "instruction": "あやしいところを見つけよう",
      "segments": [
        { "id": "s1", "text": "本文です。" }
      ],
      "correctSegmentIds": ["s1"],
      "explanation": "解説",
      "verificationTip": "確認のしかた",
      "hint": "ヒント",
      "recommendedReasonTags": ["gutFeeling"]
    }
  ]
}
```

manifest 形式のほうが、運営更新では扱いやすいです。

- `contentVersion` で差し替え管理しやすい
- `updatedAt` があると確認しやすい
- 将来 `minimumAppVersion` などを足しやすい

## 運営更新の流れ

1. 問題案を作る
2. 禁止テーマと危険表現を確認する
3. JSON バリデーションを通す
4. ステージング URL に置いてアプリで確認する
5. 問題タイトル、解説、正答箇所を再確認する
6. 本番 URL の manifest を更新する

## 実運用で追加したいもの

- 運営用の CMS か Supabase テーブル
- 下書き、審査中、公開済みの状態管理
- 危険語チェック
- 問題ごとのレビュー履歴
- 問題の無効化フラグ

## 注意

- `content_config.json` 自体はアプリに含まれるので、あとから変えたいものではなく「固定の配信先 URL」を持たせる用途です
- 公開後に配信先を切り替える可能性があるなら、将来は Remote Config や自前の設定 endpoint を足すと安全です
