# Semgrep

パターンベースの静的解析ツール。セキュリティ脆弱性、バグ、コーディング規約違反をコードパターンのマッチングで検出する。多数の言語に対応。

## インストール

```bash
brew install semgrep
```

`Brewfile` で管理。

## 基本的な使い方

```bash
# 推奨ルールセットでスキャン
semgrep scan --config auto

# 特定のルールセットを指定してスキャン
semgrep scan --config p/javascript

# 特定ディレクトリをスキャン
semgrep scan --config auto src/

# カスタムルールでスキャン
semgrep scan --config my-rules.yml

# JSON形式で結果を出力
semgrep scan --config auto --json
```

## 主要コマンド

| コマンド | 説明 |
| --- | --- |
| `semgrep scan [OPTIONS] [TARGETS]` | ルールに基づいてファイルをスキャンする（デフォルトコマンド） |
| `semgrep ci` | gitのdiffに対してスキャンを実行する（CI向け） |
| `semgrep login` / `logout` | semgrep.devへの認証・ログアウト |
| `semgrep install-semgrep-pro` | Pro Engineをインストールする |
| `semgrep lsp` | LSPサーバーを起動する（IDE連携） |
| `semgrep show` | 各種情報を表示する |
| `semgrep test` | ルールをテストする（実験的） |
| `semgrep validate` | ルールを検証する（実験的） |

## scanの主要オプション

| オプション | 説明 |
| --- | --- |
| `--config auto` | Semgrep Registryから推奨ルールを自動取得してスキャンする |
| `--config p/<ruleset>` | 特定のルールセットを使用する（例: `p/javascript`, `p/typescript`, `p/react`, `p/owasp-top-ten`） |
| `--config <file>` | カスタムルールファイルを使用する |
| `-a, --autofix` | autofixパッチを適用する |
| `--dryrun` | autofixの変更内容を適用せずに表示する（`--autofix`と併用） |
| `--baseline-commit=VAL` | 指定コミット時点では存在しなかった結果のみ表示する |
| `--dataflow-traces` | 値がどのように到達したかを説明する |
| `--json` | JSON形式で出力する |
| `--sarif` | SARIF形式で出力する |
| `--output=FILE` | 結果をファイルに保存する |
| `--severity=LEVEL` | 重要度でフィルタする（`INFO` / `WARNING` / `ERROR`） |
| `--exclude=PATTERN` | パターンに一致するファイルをスキップする |
| `--include=PATTERN` | パターンに一致するファイルのみスキャンする |
| `--error` | 検出結果がある場合にexit code 1を返す |

## ユースケース

### セキュリティ脆弱性をスキャンする

```bash
semgrep scan --config p/security-audit src/
```

SQLインジェクション、XSS、ハードコードされた秘密情報などのセキュリティ問題を検出する。

### OWASP Top 10の脆弱性をチェックする

```bash
semgrep scan --config p/owasp-top-ten src/
```

OWASP Top 10に該当する脆弱性（インジェクション、認証の不備、機密データの露出など）を検出する。

### PRの差分のみをスキャンする

```bash
semgrep scan --config auto --baseline-commit=$(git merge-base main HEAD)
```

`--baseline-commit`でmainブランチとの分岐点を指定し、PRで追加・変更された箇所の問題のみを表示する。既存コードのノイズを除外できる。

### autofixで自動修正する

```bash
# 修正内容をプレビューする
semgrep scan --config auto --autofix --dryrun

# 修正を適用する
semgrep scan --config auto --autofix
```

ルールにautofixが定義されている場合、検出した問題を自動修正する。`--dryrun`を併用すると変更内容を事前に確認できる。

### 重要度でフィルタしてスキャンする

```bash
semgrep scan --config auto --severity=ERROR
```

`--severity`でERRORレベルの問題のみに絞り込む。WARNINGやINFOレベルのノイズを除外して、重大な問題に集中できる。

### CIでコーディング規約を強制する

```bash
semgrep scan --config .semgrep.yml --error
```

プロジェクト固有のルールを`.semgrep.yml`に定義し、CIで違反を検出する。`--error`フラグにより違反があるとexit code 1を返す。

### CI専用モードでスキャンする

```bash
semgrep ci
```

`semgrep ci`はCI環境向けに最適化されたコマンド。gitのdiffベースでスキャンを行い、semgrep.devと連携して結果を管理できる。事前に`semgrep login`での認証が必要。

### フレームワーク固有のアンチパターンを検出する

```bash
# Reactのアンチパターンを検出する
semgrep scan --config p/react

# TypeScript固有の問題を検出する
semgrep scan --config p/typescript
```

React、TypeScriptなどのフレームワーク・言語固有のルールセットを使い、よくあるミスやアンチパターンを検出する。

## 参考リンク

- [Semgrep 公式サイト](https://semgrep.dev)
- [GitHub - semgrep](https://github.com/semgrep/semgrep)
- [Semgrep ルールレジストリ](https://semgrep.dev/explore)
