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

# package.json 内の全依存関係のサイズを確認
bundle-phobia -p package.json
```

## ユースケース

### パッケージ追加前にバンドルサイズを確認する

```bash
bundle-phobia date-fns dayjs moment
```

類似パッケージのバンドルサイズを比較して、軽量な選択肢を選ぶ。

### バンドルサイズの上限を設けてインストールする

```bash
bundle-phobia install some-package --max-size 100kB
```

指定サイズを超えるパッケージのインストールを防止する。

### 既存プロジェクトの依存関係のサイズを監査する

```bash
bundle-phobia -p package.json
```

現在使用しているすべての依存関係のバンドルサイズを一覧表示し、最適化の候補を見つける。

## 参考リンク

- [GitHub - bundle-phobia-cli](https://github.com/nicke/bundle-phobia-cli)
- [npm - bundle-phobia-cli](https://www.npmjs.com/package/bundle-phobia-cli)
- [BundlePhobia（Web 版）](https://bundlephobia.com)
