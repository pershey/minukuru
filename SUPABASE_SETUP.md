# Supabase Setup For Minukuru

## 方針

- 問題ファイルは Supabase の private bucket に置く
- アプリは bucket を直接読まない
- 公開用 Edge Function が `published` manifest だけ返す
- 配信は `free / premium / full` の 3 チャンネル
- 公開タイミングは `pg_cron` で管理する
- 頻度は DB 設定値で変えられるようにする

## 構成

- private bucket: `minukuru-content`
- table: `admin.question_manifests`
- table: `admin.runtime_config`
- table: `admin.source_examples`
- table: `admin.pattern_blueprints`
- table: `admin.question_drafts`
- table: `admin.review_runs`
- function: `content-manifest`
- SQL: `admin.publish_due_manifest()`
- SQL: `admin.reschedule_content_publish_job()`
- view: `admin.ready_publish_candidates`

## セキュリティ

- `service_role` は Edge Function 内だけで使う
- アプリには `anon key` しか持たせない
- Storage bucket は private のままにする
- 公開中コンテンツだけ Edge Function から返す
- 下書きや staged データにはクライアントから直接触れさせない
- Supabase project 作成時の `Enable automatic RLS` は `ON` 推奨
- `Automatically expose new tables` は `OFF` 推奨

## question_manifests の使い方

`distribution_channel` で公開面を分けます。

- `free`
  - 無料版が取得する feed
- `premium`
  - premium 購入後だけ取得する差分 feed
- `full`
  - 旧互換 / 管理確認用の統合 feed

## 更新の流れ

1. 運営が JSON を private bucket に upload
2. `question_manifests` に `distribution_channel` つきで staged レコードを作る
3. `release_at` が来たら `pg_cron` が publish SQL を実行
4. Edge Function は channel ごとの published だけ返す

premium 問題の量産側は別で、先に `source_examples -> pattern_blueprints -> question_drafts -> review_runs` を回してから、通ったものだけ manifest に載せる構成です。

## Edge Function の入口

- `full`
  - `https://<PROJECT_REF>.supabase.co/functions/v1/content-manifest`
- `free`
  - `https://<PROJECT_REF>.supabase.co/functions/v1/content-manifest?channel=free`
- `premium`
  - `https://<PROJECT_REF>.supabase.co/functions/v1/content-manifest?channel=premium`

## CLI からの運用

運営 CLI はここです。

- [pipeline.py](/Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py)
- [CONTENT_FACTORY.md](/Users/naoyaochiai/minukuru/CONTENT_FACTORY.md)

### manifest を登録する

```bash
python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  stage-manifest \
  --manifest /Users/naoyaochiai/minukuru/content_factory/output/manifest_set/free_manifest.json \
  --content-version 2026-06-27-openai-free \
  --storage-path manifests/2026-06-27-openai-free.json \
  --distribution-channel free \
  --status staged \
  --release-at now
```

### 即時 publish

```bash
python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  publish-now
```

### リモート状態確認

```bash
python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  remote-status
```

## 頻度変更

- `admin.runtime_config` に cron 式を持つ
- `select admin.reschedule_content_publish_job();` を叩くと再設定される
- 週 1 から月 1、または日次へ上げる変更も SQL 側で切り替えられる

CLI から変えるなら:

```bash
python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  set-publish-schedule \
  --cron "0 9 * * 1"
```

## アプリ側

- [content_config.json](/Users/naoyaochiai/minukuru/MinukuruApp/Resources/content_config.json) に公開入口を入れる
- アプリは `free` を通常取得し、premium 購入後は `premium` を追加取得する
- そのため製品版でも、ローカル 50 問だけで固定されず、Supabase 上の manifest を読んで拡張できる
