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

# JSON 形式で結果を出力
semgrep scan --config auto --json
```

## ユースケース

### セキュリティ脆弱性をスキャンする

```bash
semgrep scan --config p/security-audit src/
```

SQL インジェクション、XSS、ハードコードされた秘密情報などのセキュリティ問題を検出する。

### CI でコーディング規約を強制する

```bash
semgrep scan --config .semgrep.yml --error
```

プロジェクト固有のルールを `.semgrep.yml` に定義し、CI で違反を検出する。`--error` フラグにより違反があると exit code 1 を返す。

### フレームワーク固有のアンチパターンを検出する

```bash
semgrep scan --config p/react
```

React、Next.js などのフレームワーク固有のルールセットを使い、よくあるミスやアンチパターンを検出する。

## 参考リンク

- [Semgrep 公式サイト](https://semgrep.dev)
- [GitHub - semgrep](https://github.com/semgrep/semgrep)
- [Semgrep ルールレジストリ](https://semgrep.dev/explore)
