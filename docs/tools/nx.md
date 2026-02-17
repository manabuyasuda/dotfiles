# Nx

モノレポの管理・ビルドシステムツール。依存グラフの可視化、タスクキャッシュ、影響範囲の分析など、大規模プロジェクトの開発効率を向上させる。

## インストール

```bash
npm install -g nx
```

`nodenv/default-packages`で自動インストールされる。

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

## 主要コマンド

| コマンド | 説明 |
| --- | --- |
| `nx graph` | 依存グラフをブラウザで可視化する |
| `nx run <project>:<target>` | 特定プロジェクトのターゲットを実行する |
| `nx run-many -t <target>` | 複数プロジェクトに対してターゲットを一括実行する |
| `nx affected -t <target>` | 変更の影響を受けたプロジェクトのみターゲットを実行する |
| `nx show projects` | ワークスペース内の全プロジェクトを一覧表示する |
| `nx show project <name>` | 特定プロジェクトの詳細情報を表示する |
| `nx init` | 既存ワークスペースにNxを追加する |
| `nx reset` | Nxのキャッシュをクリアする |
| `nx migrate` | Nxと依存パッケージを更新する |
| `nx daemon` | Nxデーモンプロセスを管理する |

## 主要オプション

| オプション | 説明 |
| --- | --- |
| `--base=<ref>` | `affected`の比較基準となるGitリファレンス（デフォルト: `main`） |
| `--head=<ref>` | `affected`の比較対象となるGitリファレンス（デフォルト: `HEAD`） |
| `--parallel=<N>` | 並列実行するタスクの最大数 |
| `--skip-nx-cache` | キャッシュを使用せずに実行する |
| `--verbose` | 詳細なログを出力する |
| `--dry-run` | 実際には実行せず、実行内容を表示する |

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

Gitの差分から影響を受けたプロジェクトを自動検出し、必要な部分だけテスト・ビルドを実行する。CIの実行時間を短縮できる。

### 複数プロジェクトに対してターゲットを一括実行する

```bash
# 全プロジェクトのビルドを実行
nx run-many -t build

# 特定のプロジェクトのみ対象にする
nx run-many -t build --projects=app1,app2
```

`run-many`はワークスペース内の複数プロジェクトに対して同じターゲットを一括で実行する。`--projects`で対象を絞り込むことも可能。

### タスクを並列実行する

```bash
# 最大4プロセスで並列実行
nx run-many -t build --parallel=4

# 影響を受けたプロジェクトを並列テスト
nx affected -t test --parallel=3
```

`--parallel`オプションで並列数を指定し、ビルドやテストの実行時間を短縮できる。デフォルトでは3タスクが並列実行される。

### キャッシュをリセットする

```bash
nx reset
```

Nxのキャッシュやデーモンプロセスをクリアする。キャッシュが原因で予期しない動作が発生した場合に使用する。

### Nxと依存パッケージを更新する

```bash
# 更新内容を確認
nx migrate latest

# マイグレーションを実行
nx migrate --run-migrations
```

`nx migrate`はNx本体と関連パッケージのバージョンを更新する。まず`migrations.json`が生成され、内容を確認してから`--run-migrations`で適用する。

### 既存プロジェクトに段階的に導入する

```bash
npx nx@latest init
```

既存のプロジェクトにNxを追加し、タスクキャッシュだけを利用することも可能。完全なモノレポ移行は不要。

## 参考リンク

- [Nx 公式サイト](https://nx.dev)
- [GitHub - nx](https://github.com/nrwl/nx)
- [npm - nx](https://www.npmjs.com/package/nx)
