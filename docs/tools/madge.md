# Madge

JavaScript/TypeScriptプロジェクトのモジュール依存関係をグラフとして可視化するツール。循環参照の検出にも対応している。

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

# 依存関係グラフを画像として出力（Graphvizが必要）
madge --image graph.svg src/index.ts

# TypeScriptプロジェクトでtsconfigを指定
madge --ts-config tsconfig.json src/index.ts

# 特定ファイルに依存しているモジュールを表示
madge --depends src/utils/helper.ts src/
```

## 主要オプション

| オプション | 説明 |
|---|---|
| `-c, --circular` | 循環参照を検出 |
| `-d, --depends <file>` | そのファイルに依存しているモジュール一覧（逆依存） |
| `--orphans` | 誰からも参照されていない孤立モジュールを表示 |
| `--leaves` | 依存先を持たない末端モジュールを表示 |
| `-s, --summary` | 各モジュールの依存数サマリーを表示 |
| `-x, --exclude <regexp>` | 正規表現でファイルを除外 |
| `--ts-config <file>` | `tsconfig.json`を指定（パスエイリアス解決） |
| `--extensions <list>` | 拡張子を指定（例: `ts,tsx`） |
| `-i, --image <file>` | 依存グラフを画像として出力（Graphvizが必要） |
| `--dot` | DOT言語でグラフを出力（Graphviz不要） |
| `-j, --json` | JSON形式で出力 |

## ユースケース

### 循環参照をCIで検出する

```bash
madge --circular --ts-config tsconfig.json src/
```

循環参照が見つかるとexit code 1を返すため、CIに組み込んで新たな循環参照の混入を防止できる。

### 孤立ファイルを発見する

```bash
madge --orphans src/
```

どこからもimportされていないファイルを検出する。不要ファイルの削除候補を特定できる。

### 特定モジュールの影響範囲を調査する

```bash
madge --depends src/middlewares/authenticate.ts src/
```

変更予定のモジュールに依存しているファイルを一覧表示し、リファクタリングや破壊的変更の前に影響範囲を確認する。

### 末端モジュールを確認する

```bash
madge --leaves src/
```

依存先を持たない安定したモジュールを一覧表示する。変更時の影響が小さく、リファクタリングの起点にしやすい。

### 依存数サマリーで複雑度を把握する

```bash
madge --summary src/
```

各モジュールの依存数を一覧表示する。依存数が多いファイルは変更リスクが高く、分割の検討対象になる。

### 依存関係を画像で可視化する

```bash
madge --image graph.svg --ts-config tsconfig.json src/
```

Graphvizが必要。Graphvizなしで確認したい場合は`--dot`でテキスト出力できる。

```bash
madge --dot --ts-config tsconfig.json src/
```

### テストファイルを除外して本番コードだけ分析する

```bash
madge --circular --exclude '\.test\.ts$' --ts-config tsconfig.json src/
```

テストやストーリーファイルなどを除外して、本番コードの依存構造だけを分析する。

## 参考リンク

- [GitHub - madge](https://github.com/pahen/madge)
- [npm - madge](https://www.npmjs.com/package/madge)
