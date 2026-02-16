# Madge

JavaScript/TypeScript プロジェクトのモジュール依存関係をグラフとして可視化するツール。循環参照の検出にも対応している。

## インストール

```bash
npm install -g madge
```

`nodenv/default-packages` で自動インストールされる。

## 基本的な使い方

```bash
# 依存関係ツリーを表示
madge src/index.ts

# 循環参照を検出
madge --circular src/

# 依存関係グラフを画像として出力（Graphviz が必要）
madge --image graph.svg src/index.ts

# TypeScript プロジェクトで tsconfig を指定
madge --ts-config tsconfig.json src/index.ts

# 特定ファイルに依存しているモジュールを表示
madge --depends src/utils/helper.ts src/
```

## ユースケース

### 循環参照を CI で検出する

```bash
madge --circular --ts-config tsconfig.json src/
```

循環参照が見つかると exit code 1 を返すため、CI に組み込んで新たな循環参照の混入を防止できる。

### リファクタリング前に依存関係を把握する

```bash
madge --image dependency-graph.svg --ts-config tsconfig.json src/index.ts
```

大規模なリファクタリングの前に依存関係を可視化し、影響範囲を把握する。

### 特定モジュールの影響範囲を調査する

```bash
madge --depends src/lib/auth.ts --ts-config tsconfig.json src/
```

変更予定のモジュールに依存しているファイルを一覧表示し、影響範囲を確認する。

## 参考リンク

- [GitHub - madge](https://github.com/pahen/madge)
- [npm - madge](https://www.npmjs.com/package/madge)
