# Knip

プロジェクト内の未使用ファイル、未使用エクスポート、未使用の依存関係を検出するツール。不要なコードや依存関係を削減し、プロジェクトをクリーンに保つ。

## インストール

```bash
npm install -g knip
```

`nodenv/default-packages` で自動インストールされる。

## 基本的な使い方

```bash
# プロジェクトルートで未使用コードを検出
knip

# 未使用の依存関係のみ検出
knip --dependencies

# 未使用のエクスポートのみ検出
knip --exports

# 未使用のファイルのみ検出
knip --files

# 自動修正（未使用エクスポートの削除）
knip --fix
```

## ユースケース

### CI で未使用コードの混入を防止する

```bash
knip
```

CI に組み込むことで、未使用のファイル・エクスポート・依存関係が残ったままマージされることを防ぐ。

### 不要な依存関係をクリーンアップする

```bash
knip --dependencies
```

`package.json` に記載されているが実際には使われていない依存関係を検出し、削除候補を特定する。

### リファクタリング後の未使用エクスポートを検出する

```bash
knip --exports
```

リファクタリングで不要になったエクスポートを検出し、デッドコードを削除する。

## 参考リンク

- [Knip 公式サイト](https://knip.dev)
- [GitHub - knip](https://github.com/webpro-nl/knip)
- [npm - knip](https://www.npmjs.com/package/knip)
