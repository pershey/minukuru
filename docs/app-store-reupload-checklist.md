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
- build 8 を選択する
- `ミヌクル プレミアム` がアプリ内課金として紐づいていることを確認する
- 審査返信に `review-resubmission-2026-07-02.md` の文面を貼る
- 再提出する

## 4. 審査担当がたどる導線

- タイトル画面
- 右上の設定ボタン
- 設定画面の最上部 `プレミアムプラン`

## 5. 詰まった時の確認ポイント

- Paid Apps Agreement が有効か
- App Store Connect 上で IAP が `提出準備完了` 以上になっているか
- build 8 に IAP が関連付けられているか
- 返信コメントで導線を明記しているか
