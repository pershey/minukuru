# Minukuru Supabase Deploy 手順

この手順で、`private bucket + Edge Function + pg_cron + split feed` の構成をそのまま反映できます。

参照:

- [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started)
- [Database migrations](https://supabase.com/docs/guides/deployment/database-migrations)
- [Edge Functions deploy](https://supabase.com/docs/guides/functions/deploy)
- [Creating buckets](https://supabase.com/docs/guides/storage/buckets/creating-buckets)
- [Storage access control](https://supabase.com/docs/guides/storage/security/access-control)
- [pg_cron](https://supabase.com/docs/guides/database/extensions/pg_cron)

## 0. 事前に確認するもの

- Supabase の `project ref`
- Supabase CLI
- ローカルにこのリポジトリがあること

CLI がなければ:

```bash
brew install supabase/tap/supabase
```

## 1. ログインして project を link

```bash
supabase login
supabase projects list
supabase link --project-ref <YOUR_PROJECT_REF>
```

## 2. private bucket を作る

Dashboard で:

1. `Storage`
2. `New bucket`
3. 名前を `minukuru-content`
4. `Public bucket` は `OFF`

SQL で作るなら:

```sql
insert into storage.buckets (id, name, public)
values ('minukuru-content', 'minukuru-content', false)
on conflict (id) do nothing;
```

## 3. migration を反映する

このリポジトリには migration が入っています。

- [20260613090000_minukuru_content_backend.sql](/Users/naoyaochiai/minukuru/supabase/migrations/20260613090000_minukuru_content_backend.sql)
- [20260624103000_minukuru_content_factory.sql](/Users/naoyaochiai/minukuru/supabase/migrations/20260624103000_minukuru_content_factory.sql)
- [20260627113000_minukuru_distribution_channels.sql](/Users/naoyaochiai/minukuru/supabase/migrations/20260627113000_minukuru_distribution_channels.sql)
- [20260627120500_fix_publish_due_manifest_channel_ambiguity.sql](/Users/naoyaochiai/minukuru/supabase/migrations/20260627120500_fix_publish_due_manifest_channel_ambiguity.sql)
- [20260627121000_fix_publish_due_manifest_update_alias.sql](/Users/naoyaochiai/minukuru/supabase/migrations/20260627121000_fix_publish_due_manifest_update_alias.sql)

反映:

```bash
supabase db push --yes
```

## 4. Edge Function を deploy する

関数本体:

- [content-manifest/index.ts](/Users/naoyaochiai/minukuru/supabase/functions/content-manifest/index.ts)

deploy:

```bash
supabase functions deploy content-manifest --no-verify-jwt
```

## 5. 関数 URL を確認する

- `full`
  - `https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/content-manifest`
- `free`
  - `https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/content-manifest?channel=free`
- `premium`
  - `https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/content-manifest?channel=premium`

最初は `No published manifest found.` が返っても正常です。

## 6. manifest set を作る

```bash
python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  build-manifest-set \
  --drafts /Users/naoyaochiai/minukuru/content_factory/output/generated_drafts.jsonl \
  --reviews /Users/naoyaochiai/minukuru/content_factory/output/reviews.jsonl \
  --base-manifest /Users/naoyaochiai/minukuru/MinukuruApp/Resources/questions.json \
  --content-version-prefix 2026-06-27-openai \
  --out-dir /Users/naoyaochiai/minukuru/content_factory/output/manifest_set
```

## 7. Storage へ upload する

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

## 8. staged manifest を登録する

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
```

## 9. 即時公開する

```bash
python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  publish-now
```

確認:

```bash
python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  remote-status
```

## 10. cron の頻度を変える

週 1:

```bash
python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  set-publish-schedule \
  --cron "0 9 * * 1"
```

月 1:

```bash
python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  set-publish-schedule \
  --cron "0 9 1 * *"
```

## 11. アプリ側の URL

[content_config.json](/Users/naoyaochiai/minukuru/MinukuruApp/Resources/content_config.json) は次の構成です。

```json
{
  "remoteQuestionsURL": "https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/content-manifest",
  "remoteFreeQuestionsURL": "https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/content-manifest?channel=free",
  "remotePremiumQuestionsURL": "https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/content-manifest?channel=premium",
  "minimumFetchIntervalMinutes": 180,
  "minimumPremiumFetchIntervalMinutes": 15,
  "freeQuestionLimit": 50
}
```

## 12. いまのデモ配信状態

このリポジトリ作業時点では、project `jlvuhkofnnkbkwvwkhze` に次を publish 済みです。

- `demo-20260627-openai-free`
- `demo-20260627-openai-premium`
- `demo-20260627-openai-full`

## トラブル時

### 関数が 401

- `--no-verify-jwt` で deploy したか

### 関数が 404

- `published` レコードがまだない
- `channel` ごとの publish が終わっていない

### `publish-now` で失敗する

- `admin.publish_due_manifest()` を更新する migration が最後まで入っているか
- `supabase db push --yes` を再実行する

### cron が動かない

- `pg_cron` が有効か
- `cron.job` に `minukuru_publish_content` があるか
- `cron.job_run_details` に失敗ログがないか
