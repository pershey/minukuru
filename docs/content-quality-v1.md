# 1.1: 基準問題と内容審査

今回の区切りは、基準問題の整備と内容審査の強化です。大量ストックの生成と配信の分割は次の工程です。

## 基準問題

`content_factory/quality/gold_questions.json` は小学校高学年以上を想定する30問の編集基準候補です。5モード各6問で、注意が必要な表現、情報不足、問題のある表現が見当たらない場面、次の行動を含みます。既存の子供向け代表11問も参照用に収録しています。

専門家の合意、子供による試用、モデルの実測は未実施です。検証済みの正解データと表示しません。新しい19問はアプリへ自動追加せず、未配信の無料の基準候補としてリポジトリに置きます。プレミアムの生成ストックは含みません。

各問には学習目標、判断の根拠、参照資料IDを付けます。資料のURL・確認日・確認した要点は `reference_catalog.json` に管理します。教育方針の資料だけで、個別の自然科学の事実などを確認済みにはできません。

```bash
python3 tools/content_factory/benchmark.py validate
python3 tools/content_factory/benchmark.py export-inputs \
  --out content_factory/output/benchmark/drafts.jsonl
```

## 生成前の編集

素材の `editorialBrief` に、1問で教えたいことと根拠を記入します。

```json
{
  "learningObjective": "急ぐよう求められても、申し込む前に条件を確認する。",
  "factBasis": "fictionalScenario",
  "evidenceNotes": "架空の案内の条件だけから判断する。期限があることだけで嘘とは断定しない。",
  "sourceIds": ["caa-advertising-conditions"]
}
```

これがない場合は生成APIを呼ぶ前に停止します。外部の事実を扱う場合は `primarySources` を指定し、その事実を確認した資料を `scope: factual` として登録します。資料の内容を確認せず、URLだけを追加してはいけません。

## 内容審査

1. ルールの一次確認で形式・長さ・既存問題との近さを検査します。同じバッチ内も双方向に比較し、`--stock-drafts` で未公開ストックを加えられます。文字列中心の比較のため、意味の重複をすべて検出する保証はありません。
2. 作成モデルと別のモデルに、正解・解説・ヒント・選択肢の意味タグを伏せて解かせます。
3. 内容レビュアーが、正解、根拠、対象年齢、解説との一致、次の行動の5項目を `pass/fail/uncertain` で判定します。
4. 解答が一致し、5項目がすべて通ったものを、人の確認へ回します。AI同士の一致や数値スコアだけで承認済みとはしません。
5. 人が本文・選択肢・解説・資料・ひらがなの意味を確認して、採用・再生成・見送りを決めます。未解消の懸念があるものは修正後に再審査します。

以下は実行すると費用が発生する例です。認証とモデル名は運営環境で明示設定します。既存の出力ファイルを上書きせず、中断時にAPIを自動再試行しません。

```bash
python3 tools/content_factory/pipeline.py run-review \
  --drafts content_factory/output/benchmark/drafts.jsonl \
  --provider openai --model "$MINUKURU_REVIEW_MODEL" \
  --solver-provider gemini --solver-model "$MINUKURU_SOLVER_MODEL" \
  --briefs content_factory/quality/editorial_briefs.json \
  --limit 10 --max-api-calls 20 \
  --out content_factory/output/benchmark/reviews-01.jsonl
```

1問につき最大2回のAPI呼び出しを予定し、バッチ全体を実行前に検査します。中断時は保存済みの結果とプロバイダーの実行履歴を確認します。30問の評価には60回分の予算が必要です。上の例は先頭10問だけです。全件の測定を意図して行う場合は、`--limit 30 --max-api-calls 60` を明示します。

新しく生成した問題は、素材からコピーされた `sourceSnapshot.editorialBrief` も利用できます。`--briefs` は問題IDをキーとする編集メモの上書きです。デフォルトのファイルは基準問題30問専用です。

全30問の実際の審査結果を揃えたら、基準解答との一致を確認できます。

```bash
python3 tools/content_factory/benchmark.py evaluate \
  --reviews content_factory/output/benchmark/all-reviews.jsonl \
  --out content_factory/output/benchmark/evaluation.json
```

ここでの一致率は編集基準候補との一致率です。子供の学習効果や専門家との一致率ではありません。誤った問題の見逃し率や基準解答の妥当性は、今後の人による校正・試用で確認します。

## 人の確認と公開候補

### Claude Codeで手元の下書きを審査する

契約アカウントでログインしたClaude Codeでも、正解を伏せた解答と内容審査を行えます。1回につき最大20問。別々のセッションで教材データだけを渡し、問題IDと実際に使用されたモデルを照合します。生成元とは別モデルで解き、審査後に人の採用を受ける条件は同じです。

```bash
python3 tools/content_factory/pipeline.py run-review \
  --drafts content_factory/output/drafts.jsonl \
  --existing-manifest content_factory/output/comparison.json \
  --provider claude --solver-provider claude \
  --solver-model "$MINUKURU_CLAUDE_SOLVER_MODEL" \
  --model "$MINUKURU_CLAUDE_REVIEW_MODEL" \
  --limit 20 --max-api-calls 2 \
  --out content_factory/output/reviews-claude-01.jsonl
```

モデルは別名ではなく完全なIDを指定します。`--max-api-calls 2` はCLIの呼び出し数で、モデルの内部ターン数ではありません。既存出力を上書きせず、解答と内容審査の生の応答はそれぞれ `.claude-blind.json` と `.claude-semantic.json` として隣に残します。未公開の原稿・答え・審査応答をGitに入れないでください。DB上の実行種別は既存の `script` を使い、作成元・解答元・審査元は審査証跡に記録します。

### 採用する

既存の `render_review_dashboard.py` → 判定JSON → `prepare-human-review` の経路を使います。ルール確認だけの問題は採用できません。問題全文、ひらがな表示、正解、素材、作成元、内容審査結果を保存済み判定に結び付けます。変更後は画面を作り直して再判定してください。旧画面の判定は再利用できません。

`assemble-manifest` と `build-manifest-set` の `--reviews` には、最終的な `human_reviews.jsonl` を指定します。Supabaseからの `export-ready-manifest` でも、最新の人手採用判定、問題、根拠資料との一致を再確認します。

`--base-manifest` は運営が確認した既存の配信物を継承する入力です。未知の下書きをここへ混ぜて審査を迂回しないでください。Storageへのアップロードと本番配信の切り替えは、別途承認する工程です。

## フィードバック

結果画面の「この問題について伝える」から種類と任意のメモを入力します。問題ID・問題の版・アプリの版を含む内容をプレビューし、既存サポート宛てのメールを開くか、OSの共有を選べます。自動送信はしません。履歴・購入情報・端末識別子・問題本文は自動添付しません。

届いた意見は問題IDと版で照合し、正解への疑問・説明・文字や読み方に分けて見直します。正解に疑義がある問題は配信を一時停止して再審査し、修正時は版を上げます。自動集計や新しい投稿用DBは今回追加しません。

## 適用と戻し方

- アプリ候補は1.1 (13)。App Store Connectのビルド番号との重複はアップロード前に照合します。
- DBの追加migrationはありません。既存30件の状態や公開中manifestを、この開発で書き換えません。
- ホスト版を使う場合は `content-review-admin` と管理画面を同じ候補から更新します。旧RPCの指紋を新しいEdge Functionで再計算するため、新しいCLIと旧関数を混ぜると安全側に停止します。
- 過去のルール判定は履歴として残し、新しい内容審査を追加します。既存の状態名だけを根拠に承認しません。
- 公開には通常CI、現在のhead/baseに対するAIレビュー、既存のApple Sandbox/v2配信検証、固定した候補への最終承認が必要です。
- 障害時は直前の承認済みアプリ・管理用関数に戻し、問題配信は直前の承認済みmanifestを維持します。DBデータや審査履歴は削除しません。
