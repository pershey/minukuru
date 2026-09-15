# ミヌクル問題レビュー運用

プレミアム問題本文と正解を公開リポジトリへ置かず、ローカルまたは認証済みの運営画面でレビューするための手順です。

## ローカルレビュー

```bash
python3 tools/content_factory/render_review_dashboard.py \
  --drafts content_factory/output/premium_launch_20260712/openai_generated_drafts.jsonl \
  --reviews content_factory/output/premium_launch_20260712/openai_rulebased_reviews.jsonl \
  --out content_factory/output/premium_launch_20260712/review_dashboard.html \
  --title "ミヌクル プレミアム問題レビュー"
```

画面内で「採用」「再生成」「見送り」を選び、「判定を保存」から `human_review_decisions.json` を保存します。再生成・見送りにはメモが必要です。判定はブラウザにも一時保存されます。

## 判定結果を処理する

```bash
python3 tools/content_factory/pipeline.py \
  prepare-human-review \
  --drafts content_factory/output/premium_launch_20260712/openai_generated_drafts.jsonl \
  --reviews content_factory/output/premium_launch_20260712/openai_rulebased_reviews.jsonl \
  --tasks content_factory/output/premium_launch_20260712/generation_tasks.jsonl \
  --decisions /path/to/human_review_decisions.json \
  --out-dir content_factory/output/premium_launch_20260712/human_review
```

出力:

- `approved_drafts.jsonl`: 採用した下書き
- `human_reviews.jsonl`: Supabase取り込み・manifest生成に使う人手レビュー
- `regeneration_tasks.jsonl`: 修正メモを引き継いだ再生成タスク
- `rejected_drafts.jsonl`: 見送った下書き
- `pending_drafts.jsonl`: 未判定の下書き
- `decision_summary.json`: 件数とバッチ指紋

全問判定済みを必須にする場合は `--require-complete`、Supabaseにも反映する場合は、migration適用後に `--sync` を追加します。

## 認証付きのホスト版を準備する

1. Supabase AuthのURL設定で、Site URLまたはRedirect URLに `https://pershey.github.io/minukuru/content-review-admin.html` を追加します。
2. migrationを適用します。
3. 許可する運営メールとGitHub PagesのOriginをEdge Function secretsへ登録します。
4. Edge Functionをデプロイします。
5. GitHub Pagesへ反映後、運営画面でSupabaseのPublishable keyと許可済みメールを入力します。

```bash
supabase db push

supabase secrets set \
  CONTENT_REVIEW_ADMIN_EMAILS="your-email@example.com" \
  CONTENT_REVIEW_ALLOWED_ORIGINS="https://pershey.github.io"

supabase functions deploy content-review-admin --no-verify-jwt
```

運営画面:

`https://pershey.github.io/minukuru/content-review-admin.html`

Publishable keyはSupabase Dashboardの「Project Settings」→「API Keys」で確認できます。サービスロール鍵はブラウザへ入力しません。

## セキュリティ境界

- 問題データは公開GitHub Pagesへ埋め込まない
- Edge FunctionはSupabase AuthのJWTを検証し、許可メールを照合する
- 管理テーブルはRLS有効かつ`anon`/`authenticated`から権限剥奪済み
- サービスロール鍵はEdge Function内だけで使う
- 判定ファイルはバッチ指紋を持ち、問題が更新された場合は取り込みを拒否する
- 公開manifestへの反映は、判定・再生成・確認後の別工程とする
