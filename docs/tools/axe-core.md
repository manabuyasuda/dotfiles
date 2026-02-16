# axe-core CLI

axe-core エンジンを使用した Web アクセシビリティテストの CLI ツール。WCAG 2.0/2.1/2.2 の基準に基づいてアクセシビリティ違反を検出する。

## インストール

```bash
npm install -g @axe-core/cli
```

`nodenv/default-packages` で自動インストールされる。

## 基本的な使い方

```bash
# URL を指定してアクセシビリティテスト
axe https://example.com

# 複数 URL を同時にテスト
axe https://example.com https://example.com/about

# 特定のルールのみ実行
axe https://example.com --rules color-contrast,image-alt

# 特定のルールを除外
axe https://example.com --disable color-contrast

# JSON 形式で結果を出力
axe https://example.com --save results.json
```

## ユースケース

### 開発中のページのアクセシビリティを確認する

```bash
axe http://localhost:3000
```

ローカル開発サーバーに対してテストを実行し、アクセシビリティ違反を早期に発見する。

### CI で複数ページのアクセシビリティを検証する

```bash
axe http://localhost:3000/ http://localhost:3000/about http://localhost:3000/contact
```

主要ページに対してテストを実行し、違反がある場合に CI を失敗させる。

### レポートを生成してチームで共有する

```bash
axe https://example.com --save a11y-report.json
```

JSON 形式でレポートを保存し、修正すべき違反の一覧をチームに共有する。

## 参考リンク

- [GitHub - axe-core-npm](https://github.com/dequelabs/axe-core-npm/tree/develop/packages/cli)
- [npm - @axe-core/cli](https://www.npmjs.com/package/@axe-core/cli)
- [axe-core ルール一覧](https://github.com/dequelabs/axe-core/blob/develop/doc/rule-descriptions.md)
