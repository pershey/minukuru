# ミヌクル 再提出メモ 2026-07-04

## 今回の差し戻し

- Guideline 2.1(b) - Performance - App Completeness
- 指摘内容:
  - iPad Air 11-inch (M3), iPadOS 26.5 の審査環境で、プレミアムプラン画面を読み込めなかった
- Review date:
  - July 3, 2026
- Submission ID:
  - `be1806a3-a9a6-4a80-8f76-d636840e74dc`

## 対応内容

- プレミアム商品情報の取得に自動リトライを追加
- タイトル画面から直接開ける `プレミアム` 専用画面を追加
- プレミアム画面を開いている間も、商品情報の自動再確認を続けるように変更
- 読み込み中、再試行、購入復元の状態を分かりやすく表示
- 内部向けの診断文言はリリースUIから除外

## 再提出コメント

以下を App Store Connect の返信欄にそのまま貼り付け可能です。

```text
Hello,

Thank you for the review.

We fixed the premium loading issue in version 1.0 build 9.

Changes made:
- Added automatic retry handling when loading the in-app purchase product information.
- Added a dedicated Premium page that opens directly from the title screen.
- Continued checking product availability automatically while the Premium page is open.
- Added clear loading and retry states for the premium purchase area.

How to access it:
1. Launch the app
2. Tap the “Premium” button on the title screen
3. The dedicated “プレミアム” page opens immediately

We also re-tested the app on iPad Air 11-inch (M3) simulator after the fix, and confirmed that the Premium page opens directly from the title screen.
The Premium page now opens immediately even while product information is still loading, and the app keeps retrying automatically in the background.

Thank you.
```

## ローカル確認結果

- Debug build:
  - 成功
- iPad Air 11-inch (M3) シミュレータでの起動確認:
  - タイトル画面から `プレミアムを見る` をタップして専用画面が開くことを確認
- Release archive:
  - 成功
- iPad Air 系シミュレータでのテスト:
  - 12 tests, 0 failures

## 生成済みアーカイブ

- パス:
  - `/Users/naoyaochiai/minukuru/build/Minukuru-ReviewFix.xcarchive`

## 添付候補スクリーンショット

- タイトル画面:
  - `/Users/naoyaochiai/minukuru/review_assets/iap_submission_build9/title-with-premium-button-ipad-air-11-m3.png`
- プレミアム画面:
  - `/Users/naoyaochiai/minukuru/review_assets/iap_submission_build9/premium-page-ipad-air-11-m3.png`

## 再提出前の確認

- App Store Connect で build 9 を選ぶ
- IAP `ミヌクル プレミアム` がこのバージョンに紐づいていることを確認する
- 返信欄に上のコメントを入れる
- 必要なら審査メモにも `タイトル > プレミアム` の導線を追記する
