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

## 主要オプション

### 基本操作

| オプション | 説明 |
| --- | --- |
| `-u, --upgrade` | `package.json`を更新後のバージョンで上書きする（指定しない場合は一覧表示のみ） |
| `-i, --interactive` | 依存関係ごとにインタラクティブに更新を選択する（`-u`を暗黙的に含む） |
| `-t, --target <value>` | 更新先バージョンの決定方法。`latest`（デフォルト）, `newest`, `greatest`, `minor`, `patch`, `semver`, `@tag` |
| `-m, --minimal` | semverの範囲で既に満たされているバージョンはアップグレードしない |
| `--install <value>` | 自動インストールの制御。`always`, `never`, `prompt`（デフォルト） |

### フィルタリング

| オプション | 説明 |
| --- | --- |
| `-f, --filter <p>` | 指定した文字列/ワイルドカード/glob/正規表現にマッチするパッケージのみ対象にする |
| `-x, --reject <p>` | 指定した文字列/ワイルドカード/glob/正規表現にマッチするパッケージを除外する |
| `--dep <value>` | チェック対象のセクションを指定。`dev`, `optional`, `peer`, `prod`, `packageManager`（カンマ区切り） |
| `--peer` | インストール済みパッケージのpeer dependenciesをチェックし、互換バージョンのみに絞る |

### モノレポ・ワークスペース

| オプション | 説明 |
| --- | --- |
| `-w, --workspaces` | すべてのワークスペースで実行する |
| `--workspace <s>` | 指定したワークスペースのみで実行する |
| `--deep` | カレントディレクトリ配下を再帰的に走査する（`--packageFile '**/package.json'`のエイリアス） |
| `--root` | ワークスペース指定時にルートプロジェクトも対象にする（デフォルト: `true`） |

### 安全性・検証

| オプション | 説明 |
| --- | --- |
| `-d, --doctor` | アップグレードを1つずつインストール・テストし、破壊的変更を特定する。`-u`が必要 |
| `-c, --cooldown <n>` | 公開から指定日数以上経過したバージョンのみ対象にする（サプライチェーン攻撃対策） |
| `-e, --errorLevel <n>` | 終了コードの制御。`1`: エラーなしなら0で終了。`2`: 更新不要なら0で終了（CI向け） |

### 出力・その他

| オプション | 説明 |
| --- | --- |
| `--format <value>` | 出力フォーマットの変更。`dep`, `group`, `ownerChanged`, `repo`, `time`, `lines`, `installedVersion` |
| `--jsonUpgraded` | 更新対象の依存関係をJSON形式で出力する |
| `-g, --global` | グローバルパッケージをチェックする |
| `-p, --packageManager <s>` | パッケージマネージャーを指定。`npm`, `yarn`, `pnpm`, `deno`, `bun` |
| `--cache` | バージョン情報をローカルキャッシュに保存する（デフォルト: 10分有効） |

## ユースケース

### 定期的に依存関係を更新する

```bash
ncu
ncu -u
npm install
```

更新可能なパッケージを確認し、`package.json`を更新してからインストールする。

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

正規表現フィルタでESLint関連パッケージのみを対象にして更新する。

### doctorモードで破壊的変更を特定する

```bash
ncu -d -u
```

パッケージを1つずつアップグレードし、その都度テスト（`npm test`）を実行する。テストが失敗した場合はそのアップグレードをロールバックする。カスタムテストコマンドを指定する場合は`--doctorTest`を使う。

```bash
ncu -d -u --doctorTest "npm run build && npm test"
```

### ワークスペースの依存関係を更新する

```bash
# すべてのワークスペースを一括更新
ncu -u -w

# 特定のワークスペースのみ更新
ncu -u --workspace packages/core --workspace packages/utils

# ルートプロジェクトを除外してワークスペースのみ更新
ncu -u -w --no-root
```

### モノレポ全体のpackage.jsonを再帰的にチェックする

```bash
# カレントディレクトリ配下のすべてのpackage.jsonをチェック
ncu --deep

# 再帰的にチェックして更新
ncu --deep -u
```

`--deep`はネストされたディレクトリを含むすべての`package.json`を走査する。

### cooldownで新しすぎるバージョンを除外する

```bash
# 公開から3日以上経過したバージョンのみ対象にする
ncu -u --cooldown 3

# 7日以上で、マイナーバージョンまでに限定する
ncu -u --cooldown 7 --target minor
```

公開直後のバージョンを避けることで、サプライチェーン攻撃や不安定なリリースのリスクを軽減する。

### CIで依存関係の更新を検知する

```bash
# 更新可能なパッケージがあれば終了コード1を返す
ncu --errorLevel 2
```

`--errorLevel 2`を指定すると、更新が不要な場合のみ終了コード0を返す。CIパイプラインに組み込んで、依存関係の更新漏れを検知できる。

```bash
# JSON出力と組み合わせて機械処理する
ncu --errorLevel 2 --jsonUpgraded
```

## 参考リンク

- [GitHub - npm-check-updates](https://github.com/raineorshine/npm-check-updates)
- [npm - npm-check-updates](https://www.npmjs.com/package/npm-check-updates)
