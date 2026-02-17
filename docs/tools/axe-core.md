# axe-core CLI

axe-coreエンジンを使用したWebアクセシビリティテストのCLIツール。WCAG 2.0/2.1/2.2の基準に基づいてアクセシビリティ違反を検出する。

## インストール

```bash
npm install -g @axe-core/cli
```

`nodenv/default-packages`で自動インストールされる。

## 基本的な使い方

```bash
# URLを指定してアクセシビリティテスト
axe https://example.com

# 複数URLを同時にテスト
axe https://example.com https://example.com/about

# 特定のルールのみ実行
axe https://example.com --rules color-contrast,image-alt

# 特定のルールを除外
axe https://example.com --disable color-contrast

# JSON形式で結果を出力
axe https://example.com --save results.json
```

## 主要オプション

| オプション | 説明 |
|---|---|
| `-t, --tags <list>` | タグでルールをフィルター（WCAGレベル指定等） |
| `-r, --rules <list>` | 実行するルールをIDで指定（カンマ区切り） |
| `-l, --disable <list>` | 除外するルールをIDで指定（カンマ区切り） |
| `-i, --include <selector>` | テスト対象をCSSセレクターで限定 |
| `-e, --exclude <selector>` | テスト対象からCSSセレクターで除外 |
| `-s, --save [filename]` | 結果をJSONファイルに保存 |
| `-j, --stdout` | 結果をSTDOUTにJSON出力（他の出力は抑制） |
| `-q, --exit` | 違反があればexit code 1で終了（CI向け） |
| `--load-delay <ms>` | ページ読み込み後の待機時間（ミリ秒、デフォルト: 0） |
| `--timeout <s>` | 実行タイムアウト（秒、デフォルト: 90） |
| `-b, --browser <name>` | 使用するブラウザを指定 |
| `--chrome-options <options>` | ヘッドレスChromeへのオプション |

### 主要なタグ（`--tags`に指定する値）

| タグ | 対象 |
|---|---|
| `wcag2a` | WCAG 2.0 Level A |
| `wcag2aa` | WCAG 2.0 Level AA |
| `wcag2aaa` | WCAG 2.x Level AAA |
| `wcag21a` | WCAG 2.1 Level A |
| `wcag21aa` | WCAG 2.1 Level AA |
| `wcag22aa` | WCAG 2.2 Level AA |
| `best-practice` | 業界推奨のベストプラクティス |
| `cat.color` | 色・コントラスト関連 |
| `cat.forms` | フォーム関連 |
| `cat.keyboard` | キーボード操作関連 |
| `cat.text-alternatives` | 代替テキスト関連 |
| `cat.aria` | ARIA関連 |

## ユースケース

### 開発中のページのアクセシビリティを確認する

```bash
axe http://localhost:3000
```

ローカル開発サーバーに対してテストを実行し、アクセシビリティ違反を早期に発見する。

### WCAG準拠レベルを指定してテストする

```bash
axe http://localhost:3000 --tags wcag2aa,wcag21aa
```

WCAG 2.0/2.1のLevel AAに絞ってテストする。プロジェクトの準拠目標に合わせたレベルを指定できる。

### 特定カテゴリに絞ってテストする

```bash
axe http://localhost:3000 --tags cat.color,cat.text-alternatives
```

色・コントラストと代替テキストだけに絞って検証する。特定の観点で集中的にチェックしたい場合に便利。

### ページの特定領域だけをテストする

```bash
axe http://localhost:3000 --include main --exclude nav
```

`<main>`要素内だけを対象にし、`<nav>`を除外する。新規実装した領域のみを検証したい場合に使える。

### CIで違反があればビルドを失敗させる

```bash
axe http://localhost:3000/ http://localhost:3000/about --tags wcag2aa --exit
```

`--exit`を付けると違反がある場合にexit code 1を返す。CIに組み込んでアクセシビリティの退行を防止する。

### SPAなどの遅延読み込みページをテストする

```bash
axe http://localhost:3000 --load-delay 3000
```

ページ読み込み後3秒待ってからテストを実行する。SPAのルーティングや非同期レンダリングで要素が遅れて描画されるページに対応できる。

### レポートを生成してチームで共有する

```bash
axe https://example.com --save a11y-report.json
```

JSONファイルに保存し、修正すべき違反の一覧をチームに共有する。

### スクリプトやパイプラインで結果を加工する

```bash
axe http://localhost:3000 --stdout | jq '.[] | .violations[] | {id, impact, description}'
```

`--stdout`でJSON結果をSTDOUTに出力し、`jq`等で加工できる。他のツールとの連携やカスタムレポート生成に使える。

## 参考リンク

- [GitHub - axe-core-npm](https://github.com/dequelabs/axe-core-npm/tree/develop/packages/cli)
- [npm - @axe-core/cli](https://www.npmjs.com/package/@axe-core/cli)
- [axe-core ルール一覧](https://github.com/dequelabs/axe-core/blob/develop/doc/rule-descriptions.md)
