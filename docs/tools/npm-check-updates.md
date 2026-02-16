# npm-check-updates

`package.json` の依存関係を最新バージョンに更新するツール。npm の `npm outdated` よりも柔軟なフィルタリングと更新機能を提供する。

## インストール

```bash
npm install -g npm-check-updates
```

`nodenv/default-packages` で自動インストールされる。

## 基本的な使い方

```bash
# 更新可能なパッケージを一覧表示（変更なし）
ncu

# package.json を最新バージョンに更新
ncu -u

# メジャーバージョンアップを除外して更新
ncu -u --target minor

# 特定パッケージのみ確認
ncu --filter "react,react-dom"

# 特定パッケージを除外
ncu --reject "typescript"

# インタラクティブモードで選択的に更新
ncu -i
```

## ユースケース

### 定期的に依存関係を更新する

```bash
ncu
ncu -u
npm install
```

更新可能なパッケージを確認し、`package.json` を更新してからインストールする。

### マイナー・パッチのみ安全に更新する

```bash
ncu -u --target minor
npm install
```

メジャーバージョンアップ（破壊的変更の可能性）を避け、マイナー・パッチバージョンのみ更新する。

### 特定のパッケージグループを更新する

```bash
ncu --filter "/eslint/" -u
npm install
```

正規表現フィルタで ESLint 関連パッケージのみを対象にして更新する。

## 参考リンク

- [GitHub - npm-check-updates](https://github.com/raineorshine/npm-check-updates)
- [npm - npm-check-updates](https://www.npmjs.com/package/npm-check-updates)
