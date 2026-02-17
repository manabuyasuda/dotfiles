# Redocly CLI

OpenAPIドキュメントの管理・バリデーション・バンドルツール。API仕様の品質管理やドキュメント生成を支援する。

## インストール

```bash
npm install -g @redocly/cli
```

`nodenv/default-packages`で自動インストールされる。

## 主要コマンド

| コマンド | 説明 |
| --- | --- |
| `redocly lint [apis...]` | APIまたはArazzo定義をリントする |
| `redocly bundle [apis...]` | 複数ファイルのAPI定義を1ファイルにバンドルする |
| `redocly build-docs [api]` | APIドキュメントをHTMLファイルとして生成する |
| `redocly preview` | Redoclyプロジェクトをプレビューする |
| `redocly stats [api]` | API定義の統計情報を表示する |
| `redocly split [api]` | API定義を複数ファイル構造に分割する |
| `redocly join [apis...]` | 複数のAPI定義を1つに結合する（実験的機能） |
| `redocly check-config` | Redocly設定ファイルをリントする |
| `redocly login` / `logout` | 認証の管理 |

## lintの主要オプション

| オプション | 説明 |
| --- | --- |
| `--format <format>` | 出力形式を指定する。`stylish`、`codeframe`（デフォルト）、`json`、`checkstyle`、`codeclimate`、`summary`、`markdown`、`github-actions` |
| `--max-problems <n>` | 出力する問題数の上限を指定する（デフォルト: 100） |
| `--generate-ignore-file` | 無視ファイルを生成する。既存の問題を段階的に修正する運用に便利 |
| `--skip-rule <rule>` | 特定のルールをスキップする |
| `--config <path>` | 設定ファイルのパスを指定する |

## bundleの主要オプション

| オプション | 説明 |
| --- | --- |
| `-o, --output <path>` | 出力ファイルのパスを指定する |
| `--ext <ext>` | 出力ファイルの拡張子を指定する（`json`、`yaml`、`yml`） |
| `-d, --dereferenced` | `$ref`を完全に展開したバンドルを生成する |
| `--remove-unused-components` | 未使用のコンポーネントを除去する |

## 基本的な使い方

```bash
# OpenAPIファイルをバリデーション
redocly lint openapi.yaml

# 複数ファイルに分割したOpenAPIを1ファイルにバンドル
redocly bundle openapi.yaml -o bundled.yaml

# APIドキュメントをプレビュー
redocly preview-docs openapi.yaml

# 統計情報を表示
redocly stats openapi.yaml

# $refを完全に展開してバンドル
redocly bundle openapi.yaml --dereferenced -o output.yaml
```

## ユースケース

### CIでOpenAPI仕様の品質を検証する

```bash
redocly lint openapi.yaml
```

API仕様のバリデーションをCIに組み込み、不正な定義やベストプラクティス違反を検出する。

### GitHub Actionsで結果をアノテーション表示する

```bash
redocly lint openapi.yaml --format=github-actions
```

`--format=github-actions`を指定すると、lintの警告やエラーがGitHub Actionsのアノテーションとして該当行に表示される。PRレビューの効率化に有効。

### 分割管理したOpenAPIファイルをバンドルする

```bash
redocly bundle openapi.yaml -o dist/openapi.yaml
```

`$ref`で分割管理しているOpenAPIファイルを1つにまとめ、APIゲートウェイやクライアント生成ツールに渡す。

### 大規模なAPI定義を複数ファイルに分割する

```bash
redocly split openapi.yaml --outDir ./split-output
```

単一の大きなOpenAPIファイルをパス・コンポーネントごとに複数ファイルへ分割する。分割管理に移行する際の起点として使える。

### 複数のAPI定義を1つに結合する

```bash
redocly join api-v1.yaml api-v2.yaml -o merged.yaml
```

マイクロサービスごとに管理しているAPI定義を1つに結合する。実験的機能のため、結果の検証を推奨する。

### API定義の統計情報を確認する

```bash
redocly stats openapi.yaml
```

パス数、オペレーション数、スキーマ数などの統計を表示する。API定義の規模感の把握やリファクタリングの判断材料になる。

### ignoreファイルで段階的にlintを導入する

```bash
# 現在の問題をすべて無視ファイルに記録する
redocly lint openapi.yaml --generate-ignore-file

# 以降のlintでは新規の問題のみ検出される
redocly lint openapi.yaml
```

既存プロジェクトにlintを導入する際、既存の問題を一旦無視し、新規に追加される問題のみを検出する運用ができる。既存の問題は計画的に修正していく。

### ローカルでAPIドキュメントを確認する

```bash
redocly preview-docs openapi.yaml
```

ブラウザでRedoc形式のAPIドキュメントをプレビューし、変更を即座に確認する。

## 参考リンク

- [Redocly 公式サイト](https://redocly.com)
- [GitHub - redocly-cli](https://github.com/Redocly/redocly-cli)
- [npm - @redocly/cli](https://www.npmjs.com/package/@redocly/cli)
