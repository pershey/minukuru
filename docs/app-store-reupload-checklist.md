# App Store 再アップロード手順

## 1. Xcode で archive を開く

- Xcode を開く
- `Window > Organizer`
- `Minukuru-AppStore.xcarchive` を選ぶ

## 2. App Store Connect へアップロード

- `Distribute App`
- 配布先は `App Store Connect`
- 以降は基本的にデフォルトで進める

## 3. App Store Connect 側でやること

- `ミヌクル` の 1.0 の差し戻し中バージョンを開く
- 最新 build を選択する
- `ミヌクル プレミアム` がアプリ内課金として紐づいていることを確認する
- 審査返信に `review-resubmission-2026-07-02.md` の文面を貼る
- 再提出する

## 4. 審査担当がたどる導線

- タイトル画面
- `プレミアムを見る`
- 専用 `プレミアム` 画面

## 5. 13インチ iPad スクリーンショット

- 13インチ iPad 用の寸法が必要な時は以下を使う
  - `/Users/naoyaochiai/minukuru/review_assets/iap_submission_build9_13inch/title-with-premium-button-ipad-air-13-m3.png`
  - `/Users/naoyaochiai/minukuru/review_assets/iap_submission_build9_13inch/premium-page-ipad-air-13-m3.png`
- どちらも `2048x2732`

## 6. 詰まった時の確認ポイント

- Paid Apps Agreement が有効か
- App Store Connect 上で IAP が `提出準備完了` 以上になっているか
- 最新 build に IAP が関連付けられているか
- `In-App Purchase` capability を含む build か
- 返信コメントで導線を明記しているか
