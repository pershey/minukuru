# 学習フロー改善・有料配信v2 適用手順

## 変更範囲

- 既存の買い切り商品 `com.naoyaochiai.minukuru.premium` を維持する
- 無料の正解・解説・ヒント・読み上げ・文字支援は維持する
- 代表問題へ対象、学習段階、観点、回答形式、内容版を追加する
- premium feedだけをStoreKit 2署名済み取引とApp Store Server APIの現在状態で保護する
- 既存の公開関数とDBデータは削除しない

## ローカル検証

別プロジェクトと衝突しない専用ポートを`supabase/config.toml`に設定済みです。

```bash
supabase start --exclude gotrue,realtime,storage-api,imgproxy,kong,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor
supabase db lint --local --level warning
npx --yes deno@2.9.6 check supabase/functions/content-manifest-v2/index.ts
npx --yes deno@2.9.6 test supabase/functions/content-manifest-v2/entitlement_test.ts
supabase stop
```

## migrationの互換性

`20260915231500_learning_flow_metadata.sql`は`admin.question_drafts`へ次の列を追加します。

- `audience`: 旧データは`general`
- `learning_stage`: 旧データは`challenge`
- `learning_focus`: 旧データは`evidence`
- `response_type`: 旧データは`selectSegments`
- `content_revision`: 旧データは`1`

新しいJSON属性が存在すればmigrationで取り込み、その後のinsert/updateはtriggerで同期します。
問題IDや`question_payload`は変更しません。

## 本番適用前チェック

1. `supabase migration list`で適用先project refを確認する。
2. DBバックアップと現在のEdge Functionバージョンを確認する。
3. [DEPLOY_SUPABASE.md](/Users/naoyaochiai/minukuru/DEPLOY_SUPABASE.md) のApple Secretsを設定する。
4. `supabase db push`の対象migration一覧を確認してから適用する。
5. `content-manifest-v2`だけを追加deployする。移行期間中は旧`content-manifest`を再deployしない。
6. ヘッダーなしpremium取得が`401`、free取得が`200`になることを確認する。
7. TestFlight Sandboxで購入成功、キャンセル、保留、失敗、復元、再起動後を確認する。
8. 購入済み端末でpremium問題取得後、通信を切って既存キャッシュが維持されることを確認する。
9. 新版への移行期間後、旧ビルドの利用状況を確認してから`content-manifest`を再deployし、
   `channel=free`が`200`、premium/fullが`410`になることを確認する。

## 復旧手順

- Edge Function障害: `content-manifest-v2`を直前の正常コミットへ戻して再deployする。
- アプリ取得障害: 認証なしの旧premium endpointへ戻さず、取得済みキャッシュを維持したままv2を復旧する。
- DB migration: 追加列は旧コードと共存できるため、そのまま維持する。緊急復旧で列や既存データを削除しない。
- 公開manifestの問題: 直前のpublished manifestを再度publishedにし、新規manifestをstagedへ戻す。

本番DB変更、App Store公開、価格変更は、この手順の準備だけでは実施しません。
