# Supabase Files

- `migrations/20260613090000_minukuru_content_backend.sql`
  - content manifest table
  - runtime cron config
  - publish scheduling
- `functions/content-manifest/index.ts`
  - public read endpoint for published content only

次にやること:

1. private bucket `minukuru-content` を作る
2. migration を流す
3. Edge Function `content-manifest` を deploy する
4. `content_config.json` の `remoteQuestionsURL` に function URL を入れる
