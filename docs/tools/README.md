# 開発ツール一覧

dotfiles で管理している CLI ツールのカテゴリ別インデックス。

## コード品質・静的解析

| ツール | 説明 | インストール |
|---|---|---|
| [Knip](knip.md) | 未使用のファイル・エクスポート・依存関係を検出 | npm |
| [type-coverage](type-coverage.md) | TypeScript の型カバレッジを計測 | npm |
| [Semgrep](semgrep.md) | パターンベースの静的解析ツール | brew |
| [html-validate](html-validate.md) | HTML のオフラインバリデーション | npm |

## 依存関係・モジュール分析

| ツール | 説明 | インストール |
|---|---|---|
| [Madge](madge.md) | モジュール依存関係のグラフ化 | npm |
| [dependency-cruiser](dependency-cruiser.md) | 依存関係のバリデーションと可視化 | npm |
| [Nx](nx.md) | モノレポ管理と依存グラフの可視化 | npm |

## バンドルサイズ・パフォーマンス

| ツール | 説明 | インストール |
|---|---|---|
| [bundle-phobia](bundle-phobia.md) | npm パッケージのバンドルサイズを確認 | npm |
| [Lighthouse CI](lighthouse-ci.md) | Lighthouse を CI で自動実行 | npm |

## CSS 分析

| ツール | 説明 | インストール |
|---|---|---|
| [wallace-cli](wallace-cli.md) | CSS の統計情報を分析 | npm |
| [colorguard](colorguard.md) | CSS 内の類似色を検出 | npm |

## アクセシビリティ

| ツール | 説明 | インストール |
|---|---|---|
| [axe-core CLI](axe-core.md) | axe-core によるアクセシビリティテスト | npm |

## セキュリティ

| ツール | 説明 | インストール |
|---|---|---|
| [Socket](socket.md) | npm パッケージのサプライチェーンリスクを検出 | npm |
| [Semgrep](semgrep.md) | パターンベースの静的解析・セキュリティスキャン | brew |

## API ドキュメント

| ツール | 説明 | インストール |
|---|---|---|
| [Redocly](redocly.md) | OpenAPI ドキュメントの管理・バリデーション | npm |

## デプロイ・CI/CD

| ツール | 説明 | インストール |
|---|---|---|
| [Vercel CLI](vercel.md) | Vercel プラットフォームの CLI | npm |

## ターミナル検索・ナビゲーション

| ツール | 説明 | インストール |
|---|---|---|
| [fzf](fzf.md) | 汎用のあいまい検索ツール | brew |
| [ripgrep](ripgrep.md) | grepの高速な代替（Rust製） | brew |
| [fd](fd.md) | findの現代的な代替（Rust製） | brew |

## GitHub CLI 拡張

| ツール | 説明 | インストール |
|---|---|---|
| [gh-dash](gh-dash.md) | ターミナルでPR/Issueを一覧管理するTUIダッシュボード | gh extension |
| [gh-f](gh-f.md) | fzfでPR・ブランチ・ログをインタラクティブに操作 | gh extension |
| [gh-s](gh-s.md) | GitHubリポジトリをインタラクティブに検索 | gh extension |
| [gh-notify](gh-notify.md) | GitHubの通知をコマンドラインで管理 | gh extension |
| [gh-poi](gh-poi.md) | マージ済みローカルブランチを安全に一括削除 | gh extension |
| [gh-clean-branches](gh-clean-branches.md) | リモートにないローカルブランチを安全に削除 | gh extension |

## 変更履歴分析

| ツール | 説明 | インストール |
|---|---|---|
| [git logワンライナー集](git-log-oneliners.md) | git logベースのホットスポット・結合度分析 | git（組み込み） |

## パッケージ管理

| ツール | 説明 | インストール |
|---|---|---|
| [npm-check-updates](npm-check-updates.md) | package.json の依存関係を最新バージョンに更新 | npm |
