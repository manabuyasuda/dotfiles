# wallace-cli

CSSファイルの統計情報を分析するツール。ファイルサイズ、ルール数、セレクタ数、宣言数、メディアクエリ数、ユニークな色数、フォントサイズ数、フォントファミリー数、詳細度の分布などの指標を一覧表示する。

## インストール

```bash
npm install -g wallace-cli
```

`nodenv/default-packages`で自動インストールされる。

## 基本的な使い方

```bash
# CSSファイルを分析
wallace path/to/styles.css

# JSON形式で出力
wallace path/to/styles.css --json

# stdinからの入力
cat styles.css | wallace

# リモートCSSを分析
curl -s https://example.com/styles.css | wallace
```

## 主要オプション

| オプション | 説明 |
|---|---|
| `--json` | テーブルの代わりにJSON形式で出力する |
| `--help, -h` | ヘルプを表示する |

## ユースケース

### CSSのサイズと複雑度を把握する

```bash
wallace dist/styles.css
```

ファイルサイズ、ルール数、セレクタ数、宣言数、メディアクエリ数、ユニークな色数、フォントサイズ数などの統計情報をテーブル形式で一覧表示し、CSSの肥大化や複雑度を検知する。

### JSON出力をCIパイプラインやスクリプトで活用する

```bash
wallace dist/styles.css --json
```

`--json`オプションでJSON形式の出力を得られるため、CIパイプラインでの自動チェックやスクリプトでの後処理に利用できる。

### jqと組み合わせて特定の指標を抽出する

```bash
# ファイルサイズを取得
wallace dist/styles.css --json | jq '.stylesheet.filesize'

# ユニークな色の一覧を取得
wallace dist/styles.css --json | jq '.stylesheet.declarations.uniqueColorValues'

# セレクタ数を取得
wallace dist/styles.css --json | jq '.stylesheet.selectors.total'
```

JSON出力を`jq`でフィルタリングして、必要な指標だけを取得する。CIでの閾値チェックやレポート生成に活用できる。

### リモートCSSを分析する

```bash
# 本番環境のCSSを直接分析
curl -s https://example.com/css/styles.css | wallace

# JSON形式でリモートCSSの統計を取得
curl -s https://example.com/css/styles.css | wallace --json
```

`curl`と組み合わせて、デプロイ済みのCSSを直接分析する。ローカルにファイルをダウンロードせずに本番環境の状態を確認できる。

### 複数のCSSファイルを比較する

```bash
wallace styles-a.css --json | jq '{a: .stylesheet.filesize}'
wallace styles-b.css --json | jq '{b: .stylesheet.filesize}'
```

複数のCSSファイルの統計情報をJSON形式で出力し、ファイルサイズやセレクタ数などの指標を比較する。ライブラリの選定やビルド設定の検証に使える。

### リファクタリング前後のCSSを比較する

```bash
# リファクタリング前の統計を保存
wallace old-styles.css --json > before.json

# リファクタリング後の統計を保存
wallace new-styles.css --json > after.json

# diffで差分を確認
diff <(jq '.stylesheet | {filesize, selectors: .selectors.total, declarations: .declarations.total}' before.json) \
     <(jq '.stylesheet | {filesize, selectors: .selectors.total, declarations: .declarations.total}' after.json)
```

リファクタリング前後のJSON出力を比較して、ファイルサイズの削減、セレクタ数や宣言数の変化を定量的に評価する。

### CIでCSSの肥大化を監視する

```bash
# ファイルサイズが閾値を超えたら失敗させる
SIZE=$(wallace dist/styles.css --json | jq '.stylesheet.filesize')
if [ "$SIZE" -gt 100000 ]; then
  echo "CSS file size exceeds 100KB: ${SIZE} bytes"
  exit 1
fi
```

ビルド後のCSSサイズをCIで記録し、閾値を超えた場合にビルドを失敗させる。CSSの意図しない肥大化を早期に検知できる。

## 参考リンク

- [GitHub - wallace-cli](https://github.com/projectwallace/wallace-cli)
- [npm - wallace-cli](https://www.npmjs.com/package/wallace-cli)
- [Project Wallace（Web 版）](https://www.projectwallace.com)
