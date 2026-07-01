# Minukuru Content Factory

premium 問題を安全に量産して、`free / premium / full` の3系統で配信するための運営用パイプラインです。

## ねらい

- 無料版 50 問は安定して配る
- premium 解放後は追加問題だけを別 feed で足せるようにする
- `realWorld` 問題は少数精鋭で増やす
- AI に丸投げせず、`素材 -> 型 -> 下書き -> 審査 -> 配信用 manifest` の流れを固定する

## 置いたもの

- Supabase migration
  - [20260624103000_minukuru_content_factory.sql](/Users/naoyaochiai/minukuru/supabase/migrations/20260624103000_minukuru_content_factory.sql)
  - [20260627113000_minukuru_distribution_channels.sql](/Users/naoyaochiai/minukuru/supabase/migrations/20260627113000_minukuru_distribution_channels.sql)
- schema
  - [content_factory/schemas](/Users/naoyaochiai/minukuru/content_factory/schemas)
- prompt
  - [content_factory/prompts](/Users/naoyaochiai/minukuru/content_factory/prompts)
- sample data
  - [content_factory/sample_data](/Users/naoyaochiai/minukuru/content_factory/sample_data)
- pipeline script
  - [pipeline.py](/Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py)

## Supabase 側の主なテーブル

- `admin.source_examples`
  - 赤入れ済みの素材
- `admin.pattern_blueprints`
  - 量産したい型
- `admin.question_drafts`
  - AI が出した下書き
- `admin.review_runs`
  - AI / 人間 / ルールベースの審査
- `admin.question_manifests`
  - `free / premium / full` の公開管理
- `admin.ready_publish_candidates`
  - 公開候補の view

## 配信の考え方

- `free`
  - 無料版に配る 50 問前後
  - アプリは常にこの feed を読みにいく
- `premium`
  - 購入後にだけ追加取得する差分 feed
  - `accessTier: premium` の問題だけを含む
- `full`
  - ベース + premium をまとめた検証用 / 旧互換 feed
  - 管理画面確認や legacy クライアント用

いまのアプリ実装では、起動時に `free` を取得し、購入状態が premium に変わった直後に `premium` を強制再取得して、ローカルでマージします。

## 基本フロー

1. `source_examples` に素材を集める
2. `pattern_blueprints` で型を決める
3. `build-generation-batch` で生成タスクを作る
4. `run-generation` で OpenAI か Gemini に下書きを作らせる
5. `run-review` で reviewer を回す
6. `build-manifest-set` で `free / premium / full` をまとめて作る
7. Storage へ upload し、`stage-manifest` / `publish-now` で公開する

## まず試すコマンド

### 0. Supabase に素材と型を同期する

```bash
supabase db push --yes

python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  sync-reference-data

python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  remote-status
```

### 1. 生成タスクを作る

```bash
python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  build-generation-batch \
  --out /Users/naoyaochiai/minukuru/content_factory/output/generation_tasks.jsonl
```

### 2. OpenAI か Gemini で生成する

OpenAI:

```bash
export OPENAI_API_KEY=...
export MINUKURU_OPENAI_MODEL=gpt-5-mini

python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  run-generation \
  --provider openai \
  --tasks /Users/naoyaochiai/minukuru/content_factory/output/generation_tasks.jsonl \
  --out /Users/naoyaochiai/minukuru/content_factory/output/generated_drafts.jsonl
```

Gemini:

```bash
export GEMINI_API_KEY=...
export MINUKURU_GEMINI_MODEL=gemini-2.5-flash

python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  run-generation \
  --provider gemini \
  --tasks /Users/naoyaochiai/minukuru/content_factory/output/generation_tasks.jsonl \
  --out /Users/naoyaochiai/minukuru/content_factory/output/generated_drafts.jsonl
```

### 3. review を回す

rule-based:

```bash
python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  run-review \
  --provider rulebased \
  --drafts /Users/naoyaochiai/minukuru/content_factory/output/generated_drafts.jsonl \
  --out /Users/naoyaochiai/minukuru/content_factory/output/reviews.jsonl
```

OpenAI reviewer:

```bash
python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  run-review \
  --provider openai \
  --drafts /Users/naoyaochiai/minukuru/content_factory/output/generated_drafts.jsonl \
  --out /Users/naoyaochiai/minukuru/content_factory/output/reviews.jsonl
```

### 4. draft / review を Supabase に取り込む

```bash
python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  import-drafts \
  --drafts /Users/naoyaochiai/minukuru/content_factory/output/generated_drafts.jsonl

python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  import-reviews \
  --reviews /Users/naoyaochiai/minukuru/content_factory/output/reviews.jsonl
```

### 5. 配信用 manifest set を作る

```bash
python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  build-manifest-set \
  --drafts /Users/naoyaochiai/minukuru/content_factory/output/generated_drafts.jsonl \
  --reviews /Users/naoyaochiai/minukuru/content_factory/output/reviews.jsonl \
  --base-manifest /Users/naoyaochiai/minukuru/MinukuruApp/Resources/questions.json \
  --content-version-prefix 2026-06-27-openai \
  --out-dir /Users/naoyaochiai/minukuru/content_factory/output/manifest_set
```

出力:

- `free_manifest.json`
- `premium_manifest.json`
- `full_manifest.json`
- `review_report.json`
- `manifest_set_summary.json`

### 6. Storage へ upload して公開する

```bash
supabase storage cp --linked --experimental \
  --content-type application/json \
  /Users/naoyaochiai/minukuru/content_factory/output/manifest_set/free_manifest.json \
  ss:///minukuru-content/manifests/2026-06-27-openai-free.json

supabase storage cp --linked --experimental \
  --content-type application/json \
  /Users/naoyaochiai/minukuru/content_factory/output/manifest_set/premium_manifest.json \
  ss:///minukuru-content/manifests/2026-06-27-openai-premium.json

supabase storage cp --linked --experimental \
  --content-type application/json \
  /Users/naoyaochiai/minukuru/content_factory/output/manifest_set/full_manifest.json \
  ss:///minukuru-content/manifests/2026-06-27-openai-full.json
```

```bash
python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  stage-manifest \
  --manifest /Users/naoyaochiai/minukuru/content_factory/output/manifest_set/free_manifest.json \
  --content-version 2026-06-27-openai-free \
  --storage-path manifests/2026-06-27-openai-free.json \
  --distribution-channel free \
  --status staged \
  --release-at now

python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  stage-manifest \
  --manifest /Users/naoyaochiai/minukuru/content_factory/output/manifest_set/premium_manifest.json \
  --content-version 2026-06-27-openai-premium \
  --storage-path manifests/2026-06-27-openai-premium.json \
  --distribution-channel premium \
  --status staged \
  --release-at now

python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  stage-manifest \
  --manifest /Users/naoyaochiai/minukuru/content_factory/output/manifest_set/full_manifest.json \
  --content-version 2026-06-27-openai-full \
  --storage-path manifests/2026-06-27-openai-full.json \
  --distribution-channel full \
  --status staged \
  --release-at now

python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  publish-now
```

## audienceTone の扱い

`pattern_blueprints` の `audienceTone` で文体を寄せられます。

- `childFriendly`
  - やさしい言い回し
  - ふりがな前提の短文
- `seniorFriendly`
  - 1 文を短めに
  - 確認手順を少なく
- `general`
  - 通常の文体

プロンプト側ではこの値を見て、生成文と解説文のトーンを変えるようにしてあります。

## 実際に出したサンプル

このリポジトリには、すでに生成済みのデモ出力があります。

- [content_factory/output/20260627_demo](/Users/naoyaochiai/minukuru/content_factory/output/20260627_demo)
- [manifest_set_openai](/Users/naoyaochiai/minukuru/content_factory/output/20260627_demo/manifest_set_openai)

このデモでは:

- `free`: 50 問
- `premium`: 6 問
- `full`: 56 問

まで配信確認済みです。

## 運用の考え方

- 最初に集めるのは「完成問題」より「素材」
- `standard` は量を優先して AI 量産
- `realWorld` は必ず人手レビュー
- `similarityRatio` が高いものは落とすか revise に回す
- `ready_publish_candidates` は公開候補の見える化用

## 精度を上げる仮説

- いきなり完成問題を量産するより、まず「本物っぽい素材」を厚くした方が精度が上がる
- 町名、団体名、肩書きは「架空だが生活感がある」ものに寄せると現実味が出る
- `realWorld` は 1 回生成で出すより、`standard` で型を学習させて reviewer でもう一段寄せる方が安定する
- 一般募集を始めるなら「完成問題募集」より「匿名化した素材募集」の方が安全
