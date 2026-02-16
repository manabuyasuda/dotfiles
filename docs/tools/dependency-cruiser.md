# dependency-cruiser

JavaScript/TypeScript プロジェクトの依存関係をバリデーション・可視化するツール。ルールベースで依存関係の制約を定義し、アーキテクチャの一貫性を維持できる。

## インストール

```bash
npm install -g dependency-cruiser
```

`nodenv/default-packages` で自動インストールされる。

## 基本的な使い方

```bash
# 設定ファイルを初期化
depcruise --init

# 依存関係をバリデーション
depcruise src

# 依存関係グラフを DOT 形式で出力
depcruise --output-type dot src | dot -T svg > graph.svg

# HTML レポートを生成
depcruise --output-type err-html src > report.html

# TypeScript プロジェクトで tsconfig を指定
depcruise --ts-config tsconfig.json src
```

## ユースケース

### アーキテクチャルールを CI で強制する

`.dependency-cruiser.cjs` にルールを定義し、CI で実行する。

```bash
depcruise --config .dependency-cruiser.cjs src
```

例えば「`components/` から `pages/` への依存を禁止」といったルールを設定できる。

### 依存関係グラフを可視化する

```bash
depcruise --include-only "^src" --output-type dot src | dot -T svg > deps.svg
```

`src/` 配下のモジュール間の依存関係をグラフ化し、設計の全体像を把握する。

### 循環参照を検出する

```bash
depcruise --output-type err --config .dependency-cruiser.cjs src
```

設定ファイルの `no-circular` ルールにより循環参照を検出し、レポートに出力する。

## 参考リンク

- [GitHub - dependency-cruiser](https://github.com/sverweij/dependency-cruiser)
- [npm - dependency-cruiser](https://www.npmjs.com/package/dependency-cruiser)
- [dependency-cruiser ドキュメント](https://github.com/sverweij/dependency-cruiser/tree/main/doc)
