# type-coverage

TypeScript プロジェクトの型カバレッジを計測するツール。`any` 型や型推論が不十分な箇所を検出し、型安全性の向上を支援する。

## インストール

```bash
npm install -g type-coverage
```

`nodenv/default-packages` で自動インストールされる。

## 基本的な使い方

```bash
# プロジェクトルートで型カバレッジを計測
type-coverage

# 型がついていない箇所を詳細表示
type-coverage --detail

# カバレッジの閾値を指定（CI 向け）
type-coverage --at-least 90

# strict モードで計測（any を含む型もカウント）
type-coverage --strict

# tsconfig を明示的に指定
type-coverage -p tsconfig.json
```

## 主要オプション

| オプション | 説明 |
|---|---|
| `--detail` | 型がついていない箇所をファイル名・行番号付きで表示 |
| `--at-least N` | カバレッジが N% 未満なら exit 1（CI 向け） |
| `--is N` | カバレッジが N% と一致しなければ exit 1 |
| `--strict` | `any` を含む型もカウント対象にする |
| `--cache` | キャッシュ有効化（2回目以降が速い） |
| `--update` | `package.json` の `typeCoverage` を現在の値で更新 |
| `--update-if-higher` | 前回より高い場合のみ更新（ラチェット運用向け） |
| `--show-relative-path` | 詳細表示で相対パスを使う |
| `--json-output` | 結果を JSON 形式で出力 |

### ノイズ除去オプション

特定パターンの `any` を無視して、意図的でない `any` に集中できる。

| オプション | 無視する対象 | 例 |
|---|---|---|
| `--ignore-catch` | catch の暗黙 any | `catch(e)` |
| `--ignore-nested` | 型引数内の any | `Promise<any>` |
| `--ignore-as-assertion` | as アサーション | `foo as string` |
| `--ignore-type-assertion` | 型アサーション | `<string>foo` |
| `--ignore-non-null-assertion` | 非 null アサーション | `foo!` |
| `--ignore-object` | Object 型 | `foo: Object` |
| `--ignore-empty-type` | 空の型 | `foo: {}` |

## ユースケース

### CI で型カバレッジの最低ラインを維持する

```bash
type-coverage --at-least 95
```

`tsconfig.json`のある既存プロジェクトで実行し、型カバレッジが閾値を下回った場合にCIを失敗させる。

### any 型の使用箇所を洗い出す

```bash
type-coverage --detail --strict --show-relative-path
```

リファクタリング時に `any` が残っている箇所を一覧表示し、段階的に型を付けていく。`--show-relative-path` でファイルパスが読みやすくなる。

### ノイズを除去して意図的でない any に集中する

```bash
type-coverage --detail --strict --ignore-catch --ignore-nested --ignore-as-assertion --show-relative-path
```

`catch(e)` や `Promise<any>` のような許容範囲の `any` を除外し、本当に修正すべき箇所だけを表示する。

### 特定ファイルだけチェックする（lint-staged / PR レビュー向け）

```bash
type-coverage -p tsconfig.json --detail -- src/routes/v1/auth/authId.ts
```

`--`の後にファイルパスを指定して、変更したファイルだけを対象にチェックする。lint-stagedと組み合わせれば、コミット時に変更ファイルの型カバレッジを自動検証できる。

### カバレッジのラチェット運用（下がらないようにする）

```bash
type-coverage -p tsconfig.json --update-if-higher
```

`package.json`の`typeCoverage.atLeast`が自動更新される。カバレッジが上がったら閾値も引き上げ、下がることを防ぐ。CIと組み合わせて段階的に型安全性を向上させる運用ができる。

## 参考リンク

- [GitHub - type-coverage](https://github.com/nicepkg/type-coverage)
- [npm - type-coverage](https://www.npmjs.com/package/type-coverage)
