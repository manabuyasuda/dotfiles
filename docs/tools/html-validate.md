# html-validate

HTMLのオフラインバリデーションツール。W3C仕様に基づく構文チェックに加え、アクセシビリティやベストプラクティスのルールも提供する。

## インストール

```bash
npm install -g html-validate
```

`nodenv/default-packages`で自動インストールされる。

## 基本的な使い方

```bash
# HTMLファイルをバリデーション
html-validate index.html

# globパターンで複数ファイルをバリデーション
html-validate "src/**/*.html"

# 設定ファイルを初期化
html-validate --init

# 特定のプリセットを使用
html-validate --preset html-validate:recommended index.html

# stdinからの入力
cat index.html | html-validate --stdin
```

## 主要オプション

| オプション | 説明 |
| --- | --- |
| `--ext=STRING` | 対象のファイル拡張子を指定する（カンマ区切り） |
| `-f, --formatter=FORMATTER` | 出力フォーマッターを指定する（`json`, `checkstyle`など、カンマ区切りで複数指定可） |
| `--max-warnings=INT` | 警告数がこの値を超えると終了コードが非ゼロになる |
| `-p, --preset=STRING` | 設定プリセットを指定する（デフォルト: `recommended`、カンマ区切りで複数指定可） |
| `--rule=RULE:SEVERITY` | ルールを追加で設定する（カンマ区切りで複数指定可） |
| `--stdin` | stdinからマークアップを受け取る |
| `--stdin-filename=STRING` | stdin使用時に報告されるファイル名を指定する |
| `-c, --config=STRING` | カスタム設定ファイルを使用する |
| `--init` | プロジェクトに設定ファイルを生成する |
| `--print-config` | 指定ファイルに適用される設定を出力する |

フォーマッターはカンマ区切りで複数指定でき、`formatter=/path/to/file`の形式でファイルに出力できる。

## ユースケース

### CIでHTMLの品質を担保する

```bash
html-validate "dist/**/*.html"
```

ビルド成果物のHTMLをバリデーションし、不正なマークアップがデプロイされることを防ぐ。

### 特定のプリセットを使用する

```bash
# アクセシビリティに特化したプリセットを適用
html-validate --preset html-validate:a11y "src/**/*.html"

# 複数のプリセットを組み合わせる
html-validate --preset html-validate:recommended,html-validate:a11y index.html
```

プロジェクトの要件に応じてプリセットを切り替え、チェック範囲を調整できる。

### CI向けにフォーマッターで結果を出力する

```bash
# checkstyle形式でファイルに出力（JenkinsやGitLab CIで利用）
html-validate -f checkstyle=report.xml "dist/**/*.html"

# JSON形式で標準出力に出力
html-validate -f json "dist/**/*.html"

# 通常出力とcheckstyleファイル出力を同時に行う
html-validate -f stylish,checkstyle=report.xml "dist/**/*.html"
```

CI環境で結果をパースしやすい形式で出力し、レポートとして保存できる。

### コマンドラインからルールを追加する

```bash
# インラインスタイルをエラーとして検出
html-validate --rule "no-inline-style:error" index.html

# 複数のルールを同時に指定
html-validate --rule "no-inline-style:error,prefer-native-element:warn" "src/**/*.html"
```

設定ファイルを変更せずに、一時的にルールを追加して検証できる。

### ビルド出力をstdinで検証する

```bash
# SSGのビルド出力をパイプで検証
cat dist/index.html | html-validate --stdin --stdin-filename=dist/index.html

# curlでサーバーレスポンスを検証
curl -s http://localhost:3000/about | html-validate --stdin --stdin-filename=about.html
```

`--stdin-filename`を指定すると、エラー報告にファイル名が含まれるため問題箇所の特定が容易になる。

### プロジェクト固有のルールを設定する

`.htmlvalidate.json`:

```json
{
  "extends": ["html-validate:recommended"],
  "rules": {
    "no-inline-style": "error",
    "prefer-native-element": "error"
  }
}
```

```bash
html-validate "src/**/*.html"
```

### テンプレートエンジンの出力を検証する

```bash
curl -s http://localhost:3000 | html-validate --stdin
```

サーバーサイドで生成されたHTMLの品質をチェックする。

## 参考リンク

- [html-validate 公式サイト](https://html-validate.org)
- [GitHub - html-validate](https://github.com/html-validate/html-validate)
- [npm - html-validate](https://www.npmjs.com/package/html-validate)
