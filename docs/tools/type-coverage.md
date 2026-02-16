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

# JSON 形式で出力
type-coverage --json
```

## ユースケース

### CI で型カバレッジの最低ラインを維持する

```bash
type-coverage --at-least 95
```

`tsconfig.json` のある既存プロジェクトで実行し、型カバレッジが閾値を下回った場合に CI を失敗させる。

### any 型の使用箇所を洗い出す

```bash
type-coverage --detail --strict
```

リファクタリング時に `any` が残っている箇所を一覧表示し、段階的に型を付けていく。

### 型カバレッジの推移を記録する

```bash
type-coverage --json >> coverage-log.json
```

定期的に実行し、プロジェクトの型安全性の推移を記録する。

## 参考リンク

- [GitHub - type-coverage](https://github.com/nicepkg/type-coverage)
- [npm - type-coverage](https://www.npmjs.com/package/type-coverage)
