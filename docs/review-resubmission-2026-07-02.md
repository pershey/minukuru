# ミヌクル 再提出メモ 2026-07-11

## 今回の差し戻し

- Guideline 2.1(b) - Performance - App Completeness
- 指摘内容:
  - iPhone 17 Pro Max, iOS 26.5.2 の審査環境で、アプリ内課金の購入処理中にアクティビティインジケータが止まらなかった
- Review date:
  - July 5, 2026
- Submission ID:
  - `be1806a3-a9a6-4a80-8f76-d636840e74dc`

## build 12 の対応内容

- プレミアム商品情報の取得にタイムアウトを追加
- 権利確認にタイムアウトを追加
- 購入リクエストにタイムアウトを追加
- 購入復元にタイムアウトを追加
- App Store の応答が遅い場合でも、無限に回り続けずメッセージ表示に戻るように変更
- 購入ボタンを、バックグラウンドの権利確認中でも押せるように修正
- `In-App Purchase` capability を app target に有効化
- プレミアム画面からの導線はそのまま維持
  - タイトル画面
  - `プレミアム`
  - 専用プレミアム画面

## 審査返信

以下を App Store Connect の返信欄にそのまま貼り付け可能です。

```text
Hello,

Thank you for the review.

We addressed the premium purchase flow in version 1.0 build 12.

What changed:
- We separated product loading, entitlement refresh, purchase, and restore into distinct states.
- The purchase button is no longer blocked by background entitlement checks after the premium product has loaded.
- The loading indicator is now shown only during the actual purchase or restore flow.
- We enabled the In-App Purchase capability in the app target used for this build.
- The premium screen now clearly distinguishes between:
  - product info still loading
  - product unavailable / retry needed
  - purchase available

How to test:
1. Launch the app.
2. Tap "プレミアムを見る" on the title screen.
3. Wait until the premium product is loaded.
4. Tap "プレミアムを購入する".

Expected result:
- The App Store purchase sheet opens from the premium page.
- After a successful purchase, premium access is unlocked in the app.

No login or account creation is required.

Thank you.
```

## ローカル確認結果

- Debug build:
  - 成功
- Release archive:
  - これから build 12 を作成して再アップロード
- Unit test:
  - コード上のタイムアウトテストは追加済み
  - 現在のローカル環境では `xcodebuild test` が simulator の test runner 通信エラーで失敗
  - エラー:
    - `Failed to establish communication with the test runner`

## 関連ファイル

- 審査返信文:
  - `/Users/naoyaochiai/minukuru/review_assets/app_review_reply_build12.txt`
- IAPメモ:
  - `/Users/naoyaochiai/minukuru/review_assets/app_review_iap_note.txt`
- 13インチ iPad 画像:
  - `/Users/naoyaochiai/minukuru/review_assets/iap_submission_build9_13inch/title-with-premium-button-ipad-air-13-m3.png`
  - `/Users/naoyaochiai/minukuru/review_assets/iap_submission_build9_13inch/premium-page-ipad-air-13-m3.png`
