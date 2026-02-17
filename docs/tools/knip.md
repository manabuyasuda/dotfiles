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

# 別ディレクトリのプロジェクトを解析
knip --directory path/to/project

# コンパクト表示（ファイルごとにまとめる）
knip --reporter compact
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

### 特定のエクスポートが未使用と判定される理由を追跡する

```bash
knip --trace-export MyComponent
```

未使用と報告されたエクスポートについて、なぜ未使用と判定されたかの詳細を表示する。誤検知の調査や設定の調整に役立つ。

### 特定ファイルの参照関係を追跡する

```bash
knip --trace-file src/utils/foo.ts
```

指定したファイルのエクスポートがどこから参照されているかを追跡する。ファイル削除前の影響調査に使える。

### 特定の依存がどこから参照されているか追跡する

```bash
knip --trace-dependency hono
```

指定した依存パッケージをインポートしているファイルを追跡する。依存の削除やバージョンアップの影響範囲を把握できる。

### モノレポで特定のワークスペースのみ解析する

```bash
knip --workspace packages/client
```

モノレポ環境で特定のワークスペースに絞って解析する。複数指定やグロブパターンにも対応している。

## 参考リンク

- [Knip 公式サイト](https://knip.dev)
- [GitHub - knip](https://github.com/webpro-nl/knip)
- [npm - knip](https://www.npmjs.com/package/knip)
