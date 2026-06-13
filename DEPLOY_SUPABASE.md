# Minukuru Supabase Deploy 手順

この手順で、`private bucket + Edge Function + pg_cron` の構成をそのまま反映できます。

参照:

- [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started)
- [Database migrations](https://supabase.com/docs/guides/deployment/database-migrations)
- [Edge Functions deploy](https://supabase.com/docs/guides/functions/deploy)
- [Function auth](https://supabase.com/docs/guides/functions/auth)
- [Environment variables](https://supabase.com/docs/guides/functions/secrets)
- [Creating buckets](https://supabase.com/docs/guides/storage/buckets/creating-buckets)
- [Storage access control](https://supabase.com/docs/guides/storage/security/access-control)
- [pg_cron](https://supabase.com/docs/guides/database/extensions/pg_cron)
- [Scheduling Edge Functions](https://supabase.com/docs/guides/functions/schedule-functions)

## 0. 事前に確認するもの

- Supabase の `project ref`
- Supabase CLI が入っていること
- ローカルにこのリポジトリがあること

CLI がなければ先にインストールします。

```bash
brew install supabase/tap/supabase
```

## 1. ログインして project を link

```bash
supabase login
supabase projects list
supabase link --project-ref <YOUR_PROJECT_REF>
```

`supabase link` 後は、このリポジトリの `supabase/` 配下をその project に deploy できます。

## 2. private bucket を作る

一番簡単なのは Dashboard です。

1. Supabase Dashboard を開く
2. `Storage`
3. `New bucket`
4. 名前を `minukuru-content`
5. `Public bucket` は `OFF`

SQL で作る場合は、Dashboard の SQL Editor でこれを実行します。

```sql
insert into storage.buckets (id, name, public)
values ('minukuru-content', 'minukuru-content', false)
on conflict (id) do nothing;
```

## 3. migration を反映する

このリポジトリには migration が入っています。

- [`supabase/migrations/20260613090000_minukuru_content_backend.sql`](/Users/naoyaochiai/minukuru/supabase/migrations/20260613090000_minukuru_content_backend.sql)

反映コマンド:

```bash
supabase db push
```

これで以下が入ります。

- `admin.question_manifests`
- `admin.runtime_config`
- `admin.publish_due_manifest()`
- `admin.reschedule_content_publish_job()`
- `public.get_published_manifest_metadata()`
- `pg_cron` のジョブ

## 4. Edge Function を deploy する

この関数はアプリから読む公開入口です。

- [`supabase/functions/content-manifest/index.ts`](/Users/naoyaochiai/minukuru/supabase/functions/content-manifest/index.ts)

`verify_jwt = false` は [`supabase/config.toml`](/Users/naoyaochiai/minukuru/supabase/config.toml) に入れてあります。

deploy:

```bash
supabase functions deploy content-manifest --no-verify-jwt
```

`--no-verify-jwt` は、公開読み取り関数としてアプリからそのまま呼ぶためです。Supabase docs でも、公開関数は `verify_jwt = false` が案内されています。

## 5. 関数 URL を確認する

関数 URL は通常この形です。

```text
https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/content-manifest
```

ブラウザや curl で叩いて、最初は `No published manifest found.` が返れば正常です。

```bash
curl https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/content-manifest
```

## 6. 最初の問題 JSON を upload する

まずサンプルとしてこれを使えます。

- [`REMOTE_QUESTIONS_SAMPLE.json`](/Users/naoyaochiai/minukuru/REMOTE_QUESTIONS_SAMPLE.json)

Dashboard で:

1. `Storage`
2. `minukuru-content`
3. `Upload file`
4. たとえば `manifests/2026-06-13-sample.json` で保存

## 7. staged manifest を登録する

SQL Editor で、upload したファイルパスに合わせて実行します。

```sql
insert into admin.question_manifests (
  content_version,
  storage_bucket,
  storage_path,
  status,
  release_at,
  notes
)
values (
  '2026-06-13-sample',
  'minukuru-content',
  'manifests/2026-06-13-sample.json',
  'staged',
  now(),
  'initial release'
);
```

## 8. 即時公開する

すぐ使いたいときは、これで公開状態に進めます。

```sql
select * from admin.publish_due_manifest();
```

そのあと関数を叩いて、JSON が返れば成功です。

```bash
curl https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/content-manifest
```

## 9. cron の頻度を変える

今の migration では初期値として週1回のこの cron を入れています。

- 毎週月曜 09:00 `Asia/Tokyo`
- `0 9 * * 1`

変更したいときは `admin.runtime_config` を更新してから再スケジュールします。

### 週1回

```sql
update admin.runtime_config
set value = jsonb_build_object(
  'cron', '0 9 * * 1',
  'timezone', 'Asia/Tokyo'
)
where key = 'content_publish_schedule';

select admin.reschedule_content_publish_job();
```

### 月1回

```sql
update admin.runtime_config
set value = jsonb_build_object(
  'cron', '0 9 1 * *',
  'timezone', 'Asia/Tokyo'
)
where key = 'content_publish_schedule';

select admin.reschedule_content_publish_job();
```

将来もっと流行って更新頻度を上げるなら、ここだけ差し替えればよいです。

## 10. cron の動作確認

ジョブを確認:

```sql
select jobid, jobname, schedule, active
from cron.job
where jobname = 'minukuru_publish_content';
```

実行履歴を確認:

```sql
select jobid, status, return_message, start_time, end_time
from cron.job_run_details
order by start_time desc
limit 20;
```

## 11. アプリ側の URL を入れる

このファイルを書き換えます。

- [`MinukuruApp/Resources/content_config.json`](/Users/naoyaochiai/minukuru/MinukuruApp/Resources/content_config.json)

```json
{
  "remoteQuestionsURL": "https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/content-manifest",
  "minimumFetchIntervalMinutes": 180
}
```

そのあとアプリを再ビルドすれば、起動時に裏で更新を取りにいきます。

## 12. 更新運用の基本フロー

1. 新しい JSON を `minukuru-content` に upload
2. `admin.question_manifests` に `staged` で登録
3. `release_at` を設定
4. `pg_cron` が公開タイミングで `published` に切り替える
5. アプリは次回 fetch で更新を拾う

## トラブル時

### 関数が 401

- `supabase/config.toml` に `verify_jwt = false` があるか
- deploy 時に `--no-verify-jwt` を付けたか

### 関数が 404

- staged を公開していない
- `published` レコードがまだない

### cron が動かない

- `pg_cron` が有効か
- `cron.job` に `minukuru_publish_content` があるか
- `cron.job_run_details` に失敗ログがないか

### `supabase db push` が migration の途中で失敗した

- まず migration ファイルを直してから、もう一度 `supabase db push` を実行します
- 今回の既知不具合は、`admin.reschedule_content_publish_job()` の中で `cron.schedule()` に渡す SQL 文字列の区切りが `$$` と衝突していたことです
- 修正版では `'select admin.publish_due_manifest();'` を使っています
- 失敗時点では migration は最後まで適用されていないので、通常は修正後に再度 `supabase db push` すれば進められます
- もし「すでに存在する object」と「存在しない object」が混ざって再実行しづらい場合は、Dashboard の SQL Editor で `admin.reschedule_content_publish_job()` 以降だけを手動で流すより、いったん状態を確認してから進める方が安全です

## 最短コマンドまとめ

```bash
supabase login
supabase link --project-ref <YOUR_PROJECT_REF>
supabase db push
supabase functions deploy content-manifest --no-verify-jwt
```
