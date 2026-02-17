# 開発ツール一覧

dotfilesで管理しているCLIツールのカテゴリ別インデックス。

## コード品質・静的解析

| ツール | 説明 | インストール |
|---|---|---|
| [Knip](knip.md) | 未使用ファイル・エクスポート・依存関係を検出。不要コードの削減やプロジェクトの整理に使う | npm |
| [type-coverage](type-coverage.md) | TypeScriptの型カバレッジを計測。`any`型や型推論が不十分な箇所を検出し、型安全性の向上を支援する | npm |
| [Semgrep](semgrep.md) | セキュリティ脆弱性やバグをコードパターンで検出。多言語対応で、カスタムルールも定義できる | brew |
| [html-validate](html-validate.md) | HTMLのオフラインバリデーション。W3C仕様に基づく構文チェックに加え、アクセシビリティやベストプラクティスのルールも提供する | npm |

## 依存関係・モジュール分析

| ツール | 説明 | インストール |
|---|---|---|
| [Madge](madge.md) | JS/TSのモジュール依存関係をグラフ化。循環参照の検出やリファクタリング時の影響把握に使う | npm |
| [dependency-cruiser](dependency-cruiser.md) | JS/TSの依存関係をルールベースでバリデーション・可視化。アーキテクチャの制約をCIで自動検証できる | npm |
| [Nx](nx.md) | モノレポの管理・ビルドシステム。依存グラフの可視化、タスクキャッシュ、影響範囲分析で大規模プロジェクトの開発効率を向上させる | npm |

## バンドルサイズ・パフォーマンス

| ツール | 説明 | インストール |
|---|---|---|
| [bundle-phobia](bundle-phobia.md) | npmパッケージのバンドルサイズをCLIから確認。パッケージ選定時のサイズ比較や依存関係の一括監査に使う | npm |
| [Lighthouse CI](lighthouse-ci.md) | LighthouseをCI/CDで自動実行。パフォーマンス・アクセシビリティ・SEOのスコアを継続的に監視し、退行を防止する | npm |

## CSS分析

| ツール | 説明 | インストール |
|---|---|---|
| [wallace-cli](wallace-cli.md) | CSSの統計情報を分析。ルール数、セレクター数、詳細度の分布、ユニークな色数などの指標を一覧表示する | npm |
| [colorguard](colorguard.md) | CSS内の類似色をCIEDE2000色差アルゴリズムで検出。カラーパレットの意図しない重複を整理する | npm |

## アクセシビリティ

| ツール | 説明 | インストール |
|---|---|---|
| [axe-core CLI](axe-core.md) | axe-coreエンジンによるWebアクセシビリティテスト。WCAG 2.0/2.1/2.2の基準で違反を検出する | npm |

## セキュリティ

| ツール | 説明 | インストール |
|---|---|---|
| [Socket](socket.md) | npmパッケージのサプライチェーンリスクを検出。悪意あるパッケージやタイポスクワッティングを識別する | npm |
| [Semgrep](semgrep.md) | パターンベースの静的解析・セキュリティスキャン。OWASP Top 10等のルールセットで脆弱性を検出する | brew |

## APIドキュメント

| ツール | 説明 | インストール |
|---|---|---|
| [Redocly](redocly.md) | OpenAPIドキュメントの管理・バリデーション・バンドル。API仕様のリント、プレビュー、ドキュメント生成を支援する | npm |

## デプロイ・CI/CD

| ツール | 説明 | インストール |
|---|---|---|
| [Vercel CLI](vercel.md) | Vercelプラットフォームの CLI。ローカルからのデプロイ、環境変数管理、プロジェクト設定を行う | npm |

## ターミナル検索・ナビゲーション

| ツール | 説明 | インストール |
|---|---|---|
| [fzf](fzf.md) | 汎用のあいまい検索UI。任意のリストに対してインタラクティブに絞り込みでき、あらゆるCLIワークフローに組み込める | brew |
| [ripgrep](ripgrep.md) | grepの高速な代替（Rust製）。`.gitignore`を尊重し、大規模リポジトリでの検索が劇的に速い | brew |
| [fd](fd.md) | findの現代的な代替（Rust製）。`.gitignore`尊重・正規表現対応で、直感的な構文で高速にファイルを検索する | brew |

## GitHub CLI拡張

| ツール | 説明 | インストール |
|---|---|---|
| [gh-dash](gh-dash.md) | PR/Issueを一覧管理するTUIダッシュボード。diff表示・コメント・チェックアウトをダッシュボード内で完結できる | gh extension |
| [gh-f](gh-f.md) | fzfでPR・ブランチ・ログ・ワークフロー等をインタラクティブに操作。日常のGitHub作業を高速化する | gh extension |
| [gh-s](gh-s.md) | GitHubリポジトリをインタラクティブに検索。言語・ユーザー・トピックで絞り込み、パイプ連携も可能 | gh extension |
| [gh-notify](gh-notify.md) | GitHubの通知をターミナルで表示・管理。fzfで通知の既読化・diff表示・ブラウザで開くをキーバインドで操作できる | gh extension |
| [gh-poi](gh-poi.md) | マージ済みローカルブランチを安全に一括削除。squashマージやリベースマージにも対応する | gh extension |
| [gh-clean-branches](gh-clean-branches.md) | リモートブランチが削除済みのローカルブランチを安全に削除。未プッシュの変更があるブランチは保護される | gh extension |

## 変更履歴分析

| ツール | 説明 | インストール |
|---|---|---|
| [git logワンライナー集](git-log-oneliners.md) | git logベースのホットスポット・結合度・churn・複雑度の分析 | git（組み込み） |

## パッケージ管理

| ツール | 説明 | インストール |
|---|---|---|
| [npm-check-updates](npm-check-updates.md) | package.jsonの依存関係を最新バージョンに更新。メジャー/マイナー/パッチの選択的更新やフィルタリングが可能 | npm |
