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
- [20260915110000_idempotent_review_imports.sql](/Users/naoyaochiai/minukuru/supabase/migrations/20260915110000_idempotent_review_imports.sql)
- [20260915231500_learning_flow_metadata.sql](/Users/naoyaochiai/minukuru/supabase/migrations/20260915231500_learning_flow_metadata.sql)

反映:

```bash
supabase db push --yes
```

## 4. premium 配信用の Apple 検証設定

`content-manifest-v2` は、StoreKit 2 が返す署名済み取引を Apple の公式ライブラリで検証し、
App Store Server APIでも現在の取引状態を再確認します。これにより、購入時JWSが後から
返金・失効した場合も、古いJWSだけで新しいpremium manifestを取得し続けることを防ぎます。
App Store Connect の `アプリ情報 > 一般情報 > Apple ID` にある数値を控えてください。

App Store Connectの `ユーザとアクセス > 統合 > アプリ内課金` でアプリ内課金キーを作成します。
表示されるIssuer IDとKey IDを控え、ダウンロードした`.p8`は安全な場所で保管します。
`.p8`は再ダウンロードできず、リポジトリへ追加してはいけません。

Apple の公開ルート証明書を取得し、Supabase Secrets に登録します。証明書そのものは公開情報ですが、
Secrets の値はリポジトリへ保存しません。

```bash
mkdir -p /tmp/minukuru-apple-roots
curl -fsSLo /tmp/minukuru-apple-roots/AppleRootCA-G2.cer https://www.apple.com/certificateauthority/AppleRootCA-G2.cer
curl -fsSLo /tmp/minukuru-apple-roots/AppleRootCA-G3.cer https://www.apple.com/certificateauthority/AppleRootCA-G3.cer

APPLE_ROOTS_JSON="$(jq -cn \
  --arg g2 "$(base64 < /tmp/minukuru-apple-roots/AppleRootCA-G2.cer | tr -d '\n')" \
  --arg g3 "$(base64 < /tmp/minukuru-apple-roots/AppleRootCA-G3.cer | tr -d '\n')" \
  '[$g2, $g3]')"

APPLE_IAP_PRIVATE_KEY_BASE64="$(base64 < /安全な場所/SubscriptionKey_KEYID.p8 | tr -d '\n')"

supabase secrets set \
  APPLE_ROOT_CERTIFICATES_BASE64_JSON="$APPLE_ROOTS_JSON" \
  APPLE_APP_ID="<APP_STORE_CONNECTの数値APPLE_ID>" \
  APPLE_IAP_ISSUER_ID="<アプリ内課金キーのISSUER_ID>" \
  APPLE_IAP_KEY_ID="<アプリ内課金キーのKEY_ID>" \
  APPLE_IAP_PRIVATE_KEY_BASE64="$APPLE_IAP_PRIVATE_KEY_BASE64" \
  APPLE_ENABLE_ONLINE_CHECKS="true"
```

設定名だけを確認します。値は画面共有やログへ出さないでください。

```bash
supabase secrets list
```

## 5. Edge Function を deploy する

関数本体:

- [content-manifest/index.ts](/Users/naoyaochiai/minukuru/supabase/functions/content-manifest/index.ts)
- [content-manifest-v2/index.ts](/Users/naoyaochiai/minukuru/supabase/functions/content-manifest-v2/index.ts)

deploy:

```bash
supabase functions deploy content-manifest-v2 --no-verify-jwt
```

この段階では`content-manifest`を再deployしません。リポジトリ内の新しい旧関数は無料専用ですが、
公開済み旧アプリは旧premium URLを使うため、移行期間中に置き換えると追加問題を更新できなくなります。

## 6. 関数 URL を確認する

- `full`
  - `https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/content-manifest`
- `free`
  - `https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/content-manifest?channel=free`
- `premium`（新アプリ）
  - `https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/content-manifest-v2?channel=premium`

最初は `No published manifest found.` が返っても正常です。

未購入リクエストが拒否されることも確認します。

```bash
curl -i "https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/content-manifest-v2?channel=premium"
```

期待値は `401` です。`503` の場合は手順4のSecrets不足、またはApp Store Server APIの一時障害です。

## 7. manifest set を作る

```bash
python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  build-manifest-set \
  --drafts /Users/naoyaochiai/minukuru/content_factory/output/generated_drafts.jsonl \
  --reviews /Users/naoyaochiai/minukuru/content_factory/output/reviews.jsonl \
  --base-manifest /Users/naoyaochiai/minukuru/MinukuruApp/Resources/questions.json \
  --content-version-prefix 2026-06-27-openai \
  --out-dir /Users/naoyaochiai/minukuru/content_factory/output/manifest_set
```

## 8. Storage へ upload する

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

## 9. staged manifest を登録する

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

## 10. 即時公開する

```bash
python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  publish-now
```

確認:

```bash
python3 /Users/naoyaochiai/minukuru/tools/content_factory/pipeline.py \
  remote-status
```

## 11. cron の頻度を変える

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

## 12. アプリ側の URL

[content_config.json](/Users/naoyaochiai/minukuru/MinukuruApp/Resources/content_config.json) は次の構成です。

```json
{
  "remoteQuestionsURL": "https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/content-manifest",
  "remoteFreeQuestionsURL": "https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/content-manifest?channel=free",
  "remotePremiumQuestionsURL": "https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/content-manifest-v2?channel=premium",
  "minimumFetchIntervalMinutes": 180,
  "minimumPremiumFetchIntervalMinutes": 15,
  "freeQuestionLimit": 50
}
```

## 13. 安全な公開順と復旧

1. migrationを反映する。追加列には既定値があり、旧問題はそのまま読めます。
2. Apple検証用Secretsを登録する。
3. `content-manifest-v2`をdeployし、ヘッダーなしのpremium取得が`401`になることを確認する。
4. v2 URLを含むアプリをTestFlightへ出し、Sandbox購入・復元・再起動後の取得を確認する。
5. 確認後にアプリの通常公開を判断する。旧`content-manifest`は移行期間中だけ旧ビルド互換のため維持する。
6. 最低対応バージョンの更新案内と移行期間を決め、旧ビルドの利用状況を確認する。
7. 移行完了後に限り、`supabase functions deploy content-manifest --no-verify-jwt`を実行する。
   新しい旧関数は`channel=free`だけを返し、premium/fullは`410`で拒否する。

障害時は、DBの追加列や問題データを削除せず、`content-manifest-v2`を直前の正常コミットへ戻して
再deployします。premium URLを認証なしの旧URLへ戻すことは復旧手順に含めません。アプリは通信障害だけで
購入権限や取得済みpremiumキャッシュを削除しません。追加列は旧コードから参照されないため、列削除も不要です。

詳細は [learning-flow-rollout.md](/Users/naoyaochiai/minukuru/docs/learning-flow-rollout.md) を参照してください。

## 14. いまのデモ配信状態

このリポジトリ作業時点では、project `jlvuhkofnnkbkwvwkhze` に次を publish 済みです。

- `demo-20260627-openai-free`
- `demo-20260627-openai-premium`
- `demo-20260627-openai-full`

## トラブル時

### 関数が 401

- premium v2で取引ヘッダーなしなら正常
- 購入済みアプリでも401なら、商品ID・bundle ID・取引JWSの受け渡しを確認する

### premium v2関数が503

- `APPLE_ROOT_CERTIFICATES_BASE64_JSON`、`APPLE_APP_ID`、`APPLE_IAP_ISSUER_ID`、
  `APPLE_IAP_KEY_ID`、`APPLE_IAP_PRIVATE_KEY_BASE64`が設定済みか
- `APPLE_APP_ID` はbundle IDではなく、App Store Connectの数値IDか
- Secretsが正しければApp Store Server APIの稼働状況を確認し、一時障害時は再試行する

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
