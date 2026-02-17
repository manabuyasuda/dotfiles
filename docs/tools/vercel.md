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

## 主要コマンド

### 基本

| コマンド | 説明 |
|---|---|
| `vercel deploy [path]` | デプロイを実行する（デフォルトコマンド） |
| `vercel build` | プロジェクトをローカルで`./vercel/output`にビルドする |
| `vercel dev` | ローカル開発サーバーを起動する |
| `vercel env` | 環境変数を管理する |
| `vercel link [path]` | ローカルディレクトリをVercelプロジェクトにリンクする |
| `vercel login [email]` | Vercelにログインする |
| `vercel logout` | Vercelからログアウトする |
| `vercel pull [path]` | プロジェクト設定をクラウドからローカルに取得する |
| `vercel inspect [id]` | デプロイメントの詳細情報を表示する |
| `vercel ls [app]` | デプロイメントを一覧表示する |
| `vercel open` | Vercel Dashboardをブラウザで開く |

### 高度

| コマンド | 説明 |
|---|---|
| `vercel promote [url\|id]` | 指定したデプロイメントを現在のプロダクションに昇格させる |
| `vercel rollback [url\|id]` | 以前のデプロイメントに戻す |
| `vercel redeploy [url\|id]` | 以前のデプロイメントを再ビルドしてデプロイする |
| `vercel bisect` | バグが導入されたデプロイメントを二分探索で特定する |
| `vercel alias [cmd]` | ドメインエイリアスを管理する |
| `vercel domains [name]` | ドメイン名を管理する |
| `vercel logs [url]` | デプロイメントのログを表示する |

## グローバルオプション

| オプション | 説明 |
|---|---|
| `-h, --help` | ヘルプを表示する |
| `-v, --version` | バージョンを表示する |
| `--cwd` | 作業ディレクトリを指定する |
| `-A FILE, --local-config=FILE` | ローカルの`vercel.json`のパスを指定する |
| `-d, --debug` | デバッグモードを有効にする |

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

### プロジェクト設定をローカルに同期する

```bash
vercel pull
```

クラウド上のプロジェクト設定（環境変数、`vercel.json`等）をローカルの`.vercel`ディレクトリに取得する。チームメンバー間で設定を揃えたいときや、CI環境のセットアップに使える。

### ローカルでビルドして問題を切り分ける

```bash
vercel build
```

プロジェクトをローカルで`./vercel/output`にビルドする。デプロイせずにビルドエラーを確認できるため、ビルド失敗の原因調査に役立つ。

### バグが導入されたデプロイを特定する

```bash
vercel bisect
```

`git bisect`と同様の二分探索で、問題のあるデプロイメントを特定する。対話形式で各デプロイメントの状態（正常/異常）を回答していくと、原因となったデプロイメントを絞り込める。

### 問題のあるデプロイをロールバックする

```bash
vercel rollback [url|id]
```

プロダクション環境に問題が発生したとき、以前の正常なデプロイメントに即座に戻す。再ビルドなしで切り替わるため、復旧が速い。

### デプロイメントのログを確認する

```bash
vercel logs [url]
```

デプロイメントのビルドログやサーバーレス関数の実行ログを確認する。エラーの原因調査やパフォーマンスの問題を診断するときに使える。

## 参考リンク

- [Vercel CLI 公式ドキュメント](https://vercel.com/docs/cli)
- [GitHub - vercel](https://github.com/vercel/vercel)
- [npm - vercel](https://www.npmjs.com/package/vercel)
