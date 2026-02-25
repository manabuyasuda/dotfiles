# create-next-app

Next.js プロジェクトのスキャフォールディングツール。対話形式でオプションを選択するだけで、TypeScript・ESLint・Tailwind CSS・App Router などを含む初期構成を自動生成できる。

## インストール

```bash
npm install -g create-next-app
```

`nodenv/default-packages`で自動インストールされる。`npx`経由で最新版を使うことも多い。

## 基本的な使い方

```bash
# 対話形式でプロジェクトを作成（推奨）
create-next-app my-app

# npx 経由で最新版を使う
npx create-next-app@latest my-app

# カレントディレクトリにプロジェクトを作成
create-next-app .
```

対話中に以下を選択できる：

- TypeScript を使うか
- ESLint を使うか
- Tailwind CSS を使うか
- `src/` ディレクトリを使うか
- App Router を使うか（推奨）
- Turbopack を使うか
- import エイリアス（`@/*`）をカスタマイズするか

## オプション（非対話モード）

| オプション | 説明 |
|---|---|
| `--typescript`, `--ts` | TypeScript を有効にする |
| `--tailwind` | Tailwind CSS を有効にする |
| `--eslint` | ESLint を有効にする |
| `--app` | App Router を使う |
| `--src-dir` | `src/` ディレクトリ構造を使う |
| `--turbopack` | Turbopack を有効にする |
| `--import-alias <alias>` | import エイリアスを指定する（例: `@/*`） |
| `--use-pnpm` / `--use-yarn` | パッケージマネージャーを指定する |
| `--example <name>` | 公式サンプルをテンプレートにする |
| `--yes`, `-y` | 全てデフォルト値で作成する |

## ユースケース

### 推奨構成で素早く始める

```bash
npx create-next-app@latest my-app --typescript --tailwind --app --src-dir --import-alias "@/*"
```

TypeScript + Tailwind CSS + App Router + `src/`構成で非対話的に作成する。

### 公式サンプルからプロジェクトを作成する

```bash
npx create-next-app@latest my-app --example with-supabase
```

Next.jsの公式examplesリポジトリにあるテンプレートを元に作成する。

## 参考リンク

- [Next.js 公式ドキュメント](https://nextjs.org/docs)
- [npm - create-next-app](https://www.npmjs.com/package/create-next-app)
