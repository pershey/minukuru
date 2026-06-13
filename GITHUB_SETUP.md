# Minukuru GitHub 運用メモ

このリポジトリは、そのまま GitHub 管理へ移しやすい形にしてあります。

## いま GitHub で管理できるもの

- SwiftUI アプリ本体
- ローカル問題データ
- Supabase migration
- Supabase Edge Function
- deploy 手順書
- GitHub Actions の iOS CI

## GitHub に載せないもの

- `supabase/.temp/`
- `.env` 系
- `build/`
- ローカルのデザイン素材置き場

これらは [/.gitignore](/Users/naoyaochiai/minukuru/.gitignore) で除外しています。

## GitHub に載せてもよい Supabase 側のもの

- [supabase/migrations/20260613090000_minukuru_content_backend.sql](/Users/naoyaochiai/minukuru/supabase/migrations/20260613090000_minukuru_content_backend.sql)
- [supabase/functions/content-manifest/index.ts](/Users/naoyaochiai/minukuru/supabase/functions/content-manifest/index.ts)
- [supabase/config.toml](/Users/naoyaochiai/minukuru/supabase/config.toml)

この3つで、DB 構造と配信ロジックはかなり再現できます。

## GitHub に載せない方がよい Supabase 情報

- `service_role` キー
- `anon` キーを含むメモ
- 本番の `.env`
- Dashboard 上だけで変えた未記録設定

## おすすめ運用

1. GitHub を正本にする
2. Supabase の変更はなるべく migration / function で管理する
3. Dashboard 上の手動変更は、あとで必ず migration か手順書へ反映する
4. 問題 JSON は Storage 配信にして、公開タイミングだけ DB で管理する

## 初回 GitHub 連携

まだ remote がない場合:

```bash
cd /Users/naoyaochiai/minukuru
git remote add origin <YOUR_GITHUB_REPO_URL>
git add .
git commit -m "Prepare Minukuru for TestFlight and Supabase content delivery"
git push -u origin main
```

すでに remote がある場合:

```bash
cd /Users/naoyaochiai/minukuru
git add .
git commit -m "Prepare Minukuru for TestFlight and Supabase content delivery"
git push
```

## CI

GitHub Actions は [/.github/workflows/ios-ci.yml](/Users/naoyaochiai/minukuru/.github/workflows/ios-ci.yml) にあります。

内容:

- `xcodegen generate`
- iOS Simulator build
- iOS Simulator test

署名不要の範囲で回るので、PR の基本確認に向いています。

## Supabase 側は変更できるか

できます。今回の構成なら、次の変更は GitHub 管理に載せやすいです。

- schema 追加
- テーブル追加
- RLS 方針
- `pg_cron` の publish ロジック
- Edge Function のレスポンス形式

逆に、次はコード外になりやすいです。

- Storage に実際に置く問題 JSON
- Dashboard 上での一時的な手動操作
- Supabase プロジェクトそのものの請求や認証設定の一部

## 変更頻度を上げたいとき

`pg_cron` の設定値は DB で差し替えられるようにしてあります。

例:

```sql
update admin.runtime_config
set config_value = '0 9 * * 1'
where config_key = 'content_publish_cron';

select admin.reschedule_content_publish_job();
```

この形なら、週1から月1、または逆に更新頻度を上げる変更もコード側の大改修なしで行えます。
