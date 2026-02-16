# Vercel CLI

Vercel プラットフォームの CLI ツール。ローカルからのデプロイ、環境変数の管理、プロジェクト設定などを行える。

## インストール

```bash
npm install -g vercel
```

`nodenv/default-packages` で自動インストールされる。

## 基本的な使い方

```bash
# Vercel にログイン
vercel login

# プレビューデプロイ
vercel

# プロダクションデプロイ
vercel --prod

# 環境変数を追加
vercel env add MY_VAR

# 環境変数を一覧表示
vercel env ls

# プロジェクトをリンク
vercel link
```

## ユースケース

### プレビュー環境で動作確認する

```bash
vercel
```

ブランチごとにプレビュー URL が発行され、レビュアーがデプロイ結果を確認できる。

### 環境変数を管理する

```bash
vercel env add DATABASE_URL production
vercel env ls
```

本番・プレビュー・開発の各環境に対して環境変数を設定・管理する。

### ローカルで Vercel 環境を再現する

```bash
vercel dev
```

Vercel のサーバーレス関数やルーティング設定をローカルで再現し、デプロイ前に動作確認する。

## 参考リンク

- [Vercel CLI 公式ドキュメント](https://vercel.com/docs/cli)
- [GitHub - vercel](https://github.com/vercel/vercel)
- [npm - vercel](https://www.npmjs.com/package/vercel)
