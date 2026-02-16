# Nx

モノレポの管理・ビルドシステムツール。依存グラフの可視化、タスクキャッシュ、影響範囲の分析など、大規模プロジェクトの開発効率を向上させる。

## インストール

```bash
npm install -g nx
```

`nodenv/default-packages` で自動インストールされる。

## 基本的な使い方

```bash
# プロジェクトの依存グラフをブラウザで表示
nx graph

# 特定のプロジェクトのタスクを実行
nx run my-app:build

# 影響を受けたプロジェクトのみビルド
nx affected -t build

# ワークスペース内の全プロジェクトを一覧表示
nx show projects

# タスクの実行状況を確認
nx show project my-app
```

## ユースケース

### モノレポの依存グラフを可視化する

```bash
nx graph
```

ブラウザで依存グラフが表示され、プロジェクト間の関係を視覚的に把握できる。フィルタリングや検索も可能。

### 変更の影響範囲のみをテスト・ビルドする

```bash
nx affected -t test
nx affected -t build
```

Git の差分から影響を受けたプロジェクトを自動検出し、必要な部分だけテスト・ビルドを実行する。CI の実行時間を短縮できる。

### 既存プロジェクトに段階的に導入する

```bash
npx nx@latest init
```

既存のプロジェクトに Nx を追加し、タスクキャッシュだけを利用することも可能。完全なモノレポ移行は不要。

## 参考リンク

- [Nx 公式サイト](https://nx.dev)
- [GitHub - nx](https://github.com/nrwl/nx)
- [npm - nx](https://www.npmjs.com/package/nx)
