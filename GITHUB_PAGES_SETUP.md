# Minukuru GitHub Pages セットアップ

`docs/` を GitHub Pages で公開する前提のセットアップです。

## いま実装済みのもの

- 公開ページ本体
  - [docs/index.html](/Users/naoyaochiai/minukuru/docs/index.html)
  - [docs/support.html](/Users/naoyaochiai/minukuru/docs/support.html)
  - [docs/privacy-policy.html](/Users/naoyaochiai/minukuru/docs/privacy-policy.html)
- Jekyll 無効化
  - [docs/.nojekyll](/Users/naoyaochiai/minukuru/docs/.nojekyll)
- GitHub Pages 自動デプロイ workflow
  - [.github/workflows/deploy-pages.yml](/Users/naoyaochiai/minukuru/.github/workflows/deploy-pages.yml)

## 1. GitHub に push する

まだ remote がない場合:

```bash
cd /Users/naoyaochiai/minukuru
git remote add origin <YOUR_GITHUB_REPO_URL>
git add .
git commit -m "Add GitHub Pages support and App Store submission assets"
git push -u origin main
```

すでに remote がある場合:

```bash
cd /Users/naoyaochiai/minukuru
git add .
git commit -m "Add GitHub Pages support and App Store submission assets"
git push
```

## 2. GitHub 側で Pages を有効化する

GitHub のリポジトリで:

1. `Settings`
2. `Pages`
3. `Build and deployment`
4. `Source` を `GitHub Actions` にする

この状態で `main` に push されると、`Deploy GitHub Pages` workflow が動きます。

## 3. 公開 URL

リポジトリ名が `minukuru` の場合、通常は次になります。

```text
https://<github-username>.github.io/minukuru/
https://<github-username>.github.io/minukuru/support.html
https://<github-username>.github.io/minukuru/privacy-policy.html
```

## 4. App Store Connect に貼る URL

### Support URL

```text
https://<github-username>.github.io/minukuru/support.html
```

### Privacy Policy URL

```text
https://<github-username>.github.io/minukuru/privacy-policy.html
```

### Marketing URL

必要ならトップページを使えます。

```text
https://<github-username>.github.io/minukuru/
```

## 5. 確認方法

push 後に Actions タブで `Deploy GitHub Pages` が成功していることを確認します。

成功後:

- トップ: `/`
- サポート: `/support.html`
- プライバシー: `/privacy-policy.html`

が開ければ OK です。
