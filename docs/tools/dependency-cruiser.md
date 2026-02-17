# dependency-cruiser

JavaScript/TypeScriptプロジェクトの依存関係をバリデーション・可視化するツール。ルールベースで依存関係の制約を定義し、アーキテクチャの一貫性を維持できる。

## インストール

```bash
npm install -g dependency-cruiser
```

`nodenv/default-packages`で自動インストールされる。

## 基本的な使い方

```bash
# 設定ファイルを初期化
depcruise --init

# 依存関係をバリデーション
depcruise src

# 依存関係グラフをDOT形式で出力
depcruise --output-type dot src | dot -T svg > graph.svg

# HTMLレポートを生成
depcruise --output-type err-html src > report.html
```

## 主要オプション

### フィルタリング

| オプション | 説明 |
|---|---|
| `-I, --include-only <regex>` | マッチするモジュールのみを対象にする |
| `-F, --focus <regex>` | マッチするモジュールとその直接の隣接モジュールのみ表示 |
| `--focus-depth <N>` | `--focus`の深さ（1=直接隣接、2=隣接の隣接、0=無制限） |
| `-R, --reaches <regex>` | マッチするモジュールに到達可能なすべてのモジュールを表示 |
| `-A, --affected [revision]` | 指定リビジョン以降の変更モジュール＋影響範囲を表示（デフォルト: main） |
| `-x, --exclude <regex>` | マッチするモジュールを除外 |
| `-X, --do-not-follow <regex>` | マッチするモジュールは含めるが、その先の依存は追わない |
| `-S, --collapse <regex\|N>` | フォルダー深度（数値）または正規表現でモジュールを集約 |
| `-H, --highlight <regex>` | マッチするモジュールをハイライト（dot/mermaid系で有効） |

### 出力・実行制御

| オプション | 説明 |
|---|---|
| `-c, --config [file]` | ルール設定ファイルを指定 |
| `-T, --output-type <type>` | 出力形式を指定（デフォルト: err） |
| `-f, --output-to <file>` | 出力先ファイルを指定（デフォルト: stdout） |
| `-m, --metrics` | 安定度メトリクス（結合度・不安定性）を計算 |
| `--ignore-known [file]` | 既知の違反を無視（段階的導入向け） |
| `-C, --cache` | キャッシュを有効化して高速化 |

### 主要な出力形式（`--output-type`）

| 形式 | 用途 |
|---|---|
| `err` | 違反のみ出力（CI向け、デフォルト） |
| `err-long` | 違反を理由付きで詳細表示 |
| `err-html` | 違反一覧のHTMLレポート |
| `dot` | Graphviz依存グラフ（`dot -T svg`でSVG化） |
| `ddot` | フォルダーレベルの依存グラフ |
| `archi` | 高レベルのアーキテクチャ概観（自動でフォルダー集約） |
| `mermaid` | Mermaid形式（GitHub/GitLabのMarkdownに埋め込み可能） |
| `json` | JSON形式（パイプラインでの加工用） |
| `text` | テキスト形式（grepで検索可能） |
| `metrics` | 安定度メトリクス（結合度・不安定性の指標） |
| `markdown` | Markdown形式（PRコメント向け） |

## ユースケース

### アーキテクチャルールをCIで強制する

```bash
depcruise --config .dependency-cruiser.cjs src
```

`.dependency-cruiser.cjs`にルールを定義しCIで実行する。「`components/`から`pages/`への依存を禁止」といった制約を設定できる。

### 循環参照を検出する

```bash
depcruise --config .dependency-cruiser.cjs src
```

設定ファイルの`no-circular`ルールにより循環参照を検出する。違反があるとexit code 1を返す。

### 特定モジュールとその周辺の依存関係を確認する

```bash
depcruise --include-only "^src" --focus "^src/auth" -T dot src | dot -T svg > auth-deps.svg
```

`--focus`で指定したモジュールとその直接の依存元・依存先だけを抽出してグラフ化する。大規模プロジェクトで特定領域の依存構造を把握するのに便利。

### PRの変更による影響範囲を可視化する

```bash
depcruise --affected main -T dot src | dot -T svg > affected.svg
```

mainブランチ以降に変更されたモジュールと、それに依存するすべてのモジュールを表示する。PRレビュー時の影響範囲の把握に使える。

### フォルダーレベルで依存関係を俯瞰する

```bash
depcruise --include-only "^src" -T archi src | dot -T svg > architecture.svg
```

モジュール単位ではなくフォルダー単位で依存関係を自動集約する。アーキテクチャの全体像を把握したい場合に使える。`--collapse 2`で任意の深度に集約することもできる。

### 安定度メトリクスを計算する

```bash
depcruise --metrics -T metrics src
```

各モジュール・フォルダーの求心結合度（Ca）・遠心結合度（Ce）・不安定性（I = Ce/(Ca+Ce)）を算出する。不安定性が高いモジュールはリファクタリングの優先候補になる。

### 既知の違反を無視して段階的に導入する

```bash
# 現状の違反をベースラインとして記録
depcruise-baseline src
# ベースライン以外の新規違反だけをチェック
depcruise --ignore-known src
```

既存プロジェクトに導入する際、既知の違反を`.dependency-cruiser-known-violations.json`に記録し、新規の違反だけを検出する。

### キャッシュを有効にして高速化する

```bash
depcruise --cache src
```

`node_modules/.cache/dependency-cruiser`にキャッシュが保存され、2回目以降の実行が高速になる。CIやウォッチモードでの繰り返し実行に有効。

## 参考リンク

- [GitHub - dependency-cruiser](https://github.com/sverweij/dependency-cruiser)
- [npm - dependency-cruiser](https://www.npmjs.com/package/dependency-cruiser)
- [dependency-cruiser ドキュメント](https://github.com/sverweij/dependency-cruiser/tree/main/doc)
