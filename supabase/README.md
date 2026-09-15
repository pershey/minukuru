# Supabase Files

- `migrations/20260613090000_minukuru_content_backend.sql`
  - content manifest table
  - runtime cron config
  - publish scheduling
- `functions/content-manifest/index.ts`
  - 移行完了後にdeployする無料専用の旧endpoint（premium/fullは410）
- `functions/content-manifest-v2/index.ts`
  - 無料feedは公開、有料feedはStoreKit 2署名とApp Store Server APIの現在状態をサーバー検証
- `migrations/20260915231500_learning_flow_metadata.sql`
  - 対象、学習段階、観点、回答形式、コンテンツ版の後方互換メタデータ

次にやること:

1. private bucket `minukuru-content` を作る
2. migration を流す
3. Apple検証用Secretsを設定する
4. Edge Function `content-manifest-v2` を deploy する
5. `content_config.json` の `remotePremiumQuestionsURL` にv2のfunction URLを入れる
