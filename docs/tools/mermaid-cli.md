# mermaid-cli (mmdc)

Mermaid記法で書いたダイアグラムをSVG・PNG・PDFに変換するCLIツール。`.mmd` ファイルだけでなく、Markdownファイル内のmermaidコードブロックも一括変換できる。

## インストール

```bash
npm install -g @mermaid-js/mermaid-cli
```

`nodenv/default-packages` で自動インストールされる。

## 基本的な使い方

```bash
# .mmd ファイルを SVG に変換
mmdc -i input.mmd -o output.svg

# PNG で出力
mmdc -i input.mmd -o output.png

# Markdown 内の全 mermaid ブロックを一括変換
mmdc -i README.template.md -o README.md

# stdin からパイプ入力
echo "graph TD; A-->B" | mmdc -i - -o output.svg
```

## 主要オプション

| オプション | 説明 | デフォルト |
|---|---|---|
| `-i, --input <file>` | 入力ファイル（`.mmd` または `.md`）。`-` で stdin | 必須 |
| `-o, --output [file]` | 出力ファイル。`-` で stdout | 入力ファイル名 + `.svg` |
| `-e, --outputFormat [format]` | 出力フォーマット（`svg` / `png` / `pdf`） | 拡張子から自動判定 |
| `-t, --theme [theme]` | テーマ（`default` / `forest` / `dark` / `neutral`） | `default` |
| `-b, --backgroundColor [color]` | 背景色（例: `transparent`, `#F0F0F0`） | `white` |
| `-w, --width [px]` | ページ幅 | `800` |
| `-H, --height [px]` | ページ高さ | `600` |
| `-s, --scale [factor]` | スケールファクター | `1` |
| `-c, --configFile [file]` | Mermaid 用 JSON 設定ファイル | |
| `-C, --cssFile [file]` | ページ用 CSS ファイル | |
| `-q, --quiet` | ログ出力を抑制 | |

## ユースケース

### SVG を生成する

```bash
mmdc -i diagram.mmd -o diagram.svg
```

### ダークテーマ・透過背景で PNG 出力

```bash
mmdc -i diagram.mmd -o diagram.png -t dark -b transparent
```

### Markdown のコードブロックを一括変換

```bash
mmdc -i docs.template.md -o docs.md
```

Markdown内の ` ```mermaid ` ブロックを検出し、SVGファイルを生成してリンクに差し替える。ドキュメントの自動ビルドに組み込みやすい。

### 構文チェックのみ行う

```bash
mmdc -i diagram.mmd -o /dev/null
```

出力先を `/dev/null` にすることで、ファイルを生成せずに構文エラーだけを検出できる。CIでのバリデーションに使える。

## 参考リンク

- [GitHub - mermaid-cli](https://github.com/mermaid-js/mermaid-cli)
- [npm - @mermaid-js/mermaid-cli](https://www.npmjs.com/package/@mermaid-js/mermaid-cli)
