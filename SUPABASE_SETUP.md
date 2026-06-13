# Supabase Setup For Minukuru

## 方針

- 問題ファイルは Supabase の private bucket に置く
- アプリは bucket を直接読まない
- 公開用 Edge Function が「公開済み manifest だけ」を返す
- 公開タイミングは `pg_cron` で管理する
- 頻度は DB 設定値で変えられるようにする

## 構成

- private bucket: `minukuru-content`
- table: `admin.question_manifests`
- table: `admin.runtime_config`
- function: `content-manifest`
- SQL: `admin.publish_due_manifest()`
- SQL: `admin.reschedule_content_publish_job()`

## セキュリティ

- `service_role` は Edge Function 内だけで使う
- アプリには `anon key` しか持たせない
- Storage bucket は private のままにする
- 公開中コンテンツは Edge Function から返す
- 下書きや staged データにはクライアントから直接触れさせない

## 更新の流れ

1. 運営が JSON を private bucket にアップロード
2. `question_manifests` に staged レコードを作る
3. `release_at` が来たら `pg_cron` が publish SQL を実行
4. Edge Function は published のみ返す

## 頻度変更

- `admin.runtime_config` に cron 式を持つ
- `select admin.reschedule_content_publish_job();` を叩くと再設定される
- 週1から月1へ変えるなどを SQL 側で切り替えられる

## アプリ側

- `content_config.json` の `remoteQuestionsURL` に Edge Function URL を入れる
- 返却 JSON は `REMOTE_QUESTIONS_SAMPLE.json` と同じ形でよい
