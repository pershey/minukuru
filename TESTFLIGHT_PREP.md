# Minukuru TestFlight Prep

## 現在の状態

- `xcodegen generate` 済み
- Simulator Debug build 成功
- iOS Simulator test 成功
- `generic/platform=iOS` Release build 成功
- `generic/platform=iOS` archive 成功
- ローカル archive 出力先: `build/Minukuru.xcarchive`
- App Store 向け export 成功
- `.ipa` 出力先: `build/export-appstore/Minukuru.ipa`
- Build Number: `4`
- ロゴ差し替え・透過調整済み
  - App Icon: `MinukuruApp/Resources/Assets.xcassets/AppIcon.appiconset`
  - タイトルロゴ: `TitleLogoVertical` / `MinukuruLogoView.swift`
  - 起動画面: `LaunchScreen.storyboard`
- 問題配信の土台あり
  - 起動時は bundled `questions.json`
  - 将来は `content_config.json` の URL からリモート更新可能
  - キャッシュ保存あり

## Xcode で最終確認すること

1. `xcodegen generate` を実行して最新の `Minukuru.xcodeproj` を生成する
2. Xcode で `Minukuru.xcodeproj` を開く
3. Signing & Capabilities で Team が `NRJLLKV544` になっているか確認する
4. Bundle Identifier を本番用に確定する
5. 現在の Version / Build は `1.0 (4)`。必要に応じて更新する
6. `questions.json` が Copy Bundle Resources に入っていることを確認する
7. App Icon が `Assets.xcassets/AppIcon` で設定されていることを確認する

## 実機で確認すること

1. ホームからモード選択、出題、答え合わせ、結果、次の問題まで 1 周確認する
2. ヒント表示、理由タグ選択、成績リセットを確認する
3. Dynamic Type を大きくして崩れすぎないか確認する
4. VoiceOver でセグメント、理由タグ、主要ボタンの読み上げを確認する
5. iPhone 実機で縦向き操作を確認する
6. iPad 実機またはシミュレータで回転時の崩れを確認する

## App Store Connect 用メモ

- アプリ名: ミヌクル
- サブタイトル: 嘘・詐欺・フェイクを見抜く練習
- キャッチコピー: あやしい情報を見抜こう
- 主な対象: 小学生高学年以上、ネット情報に不慣れな大人、高齢者
- 注意点: 人をだます目的ではなく、うのみにしない練習アプリ

## アップロード手順

1. Xcode で Any iOS Device を選ぶ
2. Product > Archive を実行する
3. Organizer で archive を選ぶ
4. Validate App を実行する
5. 問題なければ Distribute App > App Store Connect > Upload を進める
6. すぐにアップロードしたい場合は `build/export-appstore/Minukuru.ipa` を Transporter にドラッグしてもよい
7. TestFlight の内部テスターで実機確認する
