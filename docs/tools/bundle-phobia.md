# bundle-phobia-cli

npm パッケージのバンドルサイズ（minified + gzip）を CLI から確認するツール。パッケージ追加前にサイズの影響を評価できる。

## インストール

```bash
npm install -g bundle-phobia-cli
```

`nodenv/default-packages` で自動インストールされる。

## 基本的な使い方

```bash
# パッケージのバンドルサイズを確認
bundle-phobia lodash

# 複数パッケージを比較
bundle-phobia react react-dom

# サイズ制限付きでインストール（制限を超えたらインストールしない）
bundle-phobia install lodash --max-size 50kB

# package.jsonの全依存関係のサイズを確認
bundle-phobia -p package.json
```

## 主要オプション

| オプション | 説明 |
|---|---|
| `(引数なし) <packages..>` | パッケージのバンドルサイズを表示 |
| `install <packages..>` | サイズ条件を満たす場合のみインストール |
| `-p, --package <file>` | `package.json`を指定して全依存を一括確認 |
| `-r, --range <N>` | 直近Nバージョンのサイズ推移を表示（0で全バージョン） |
| `-s, --size` | minifiedサイズだけ出力 |
| `-g, --gzip-size` | gzipサイズだけ出力 |
| `-d, --dependencies` | 依存数だけ出力 |
| `-j, --json` | JSON形式で出力 |
| `-x, --fail-fast` | 最初のエラーで停止 |

## ユースケース

### パッケージ選定時にサイズを比較する

```bash
bundle-phobia date-fns dayjs moment
```

同じ機能の候補パッケージを並べて、バンドルサイズで比較する。

### package.jsonの全依存を一括監査する

```bash
bundle-phobia -p package.json
```

現在の依存関係すべてのサイズを一覧で確認し、重いパッケージを発見する。

### バージョン間のサイズ推移を確認する

```bash
bundle-phobia -r 5 hono
```

直近5バージョンでサイズが急増していないか確認する。アップデート前の影響評価に使える。

### サイズ上限付きでインストールする

```bash
bundle-phobia install some-package --max-size 50kB
```

指定サイズを超えるパッケージのインストールを防止する。ガードレールとして機能する。

### CI・スクリプト用に数値だけ取得する

```bash
# gzipサイズだけ出力
bundle-phobia -g lodash

# JSON形式で出力
bundle-phobia -j lodash
```

`-s`や`-g`で数値だけ、`-j`でJSON形式を取得できる。CIでのサイズチェックやスクリプトでの加工に使える。

## 参考リンク

- [GitHub - bundle-phobia-cli](https://github.com/nicke/bundle-phobia-cli)
- [npm - bundle-phobia-cli](https://www.npmjs.com/package/bundle-phobia-cli)
- [BundlePhobia（Web 版）](https://bundlephobia.com)
