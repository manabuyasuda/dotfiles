# Socket

npmパッケージのサプライチェーンリスクを検出するセキュリティツール。悪意のあるパッケージ、タイポスクワッティング、既知の脆弱性を識別する。

## インストール

```bash
npm install -g @socketsecurity/cli
```

`nodenv/default-packages`で自動インストールされる。

## 基本的な使い方

```bash
# Socket CLIのセットアップ（APIトークンの設定）
socket login

# プロジェクトのスキャンを作成
socket scan create

# パッケージのセキュリティスコアを確認
socket package score npm lodash

# npmラッパーを有効化（インストール時に自動スキャン）
socket wrapper --enable

# スキャン結果をレポートとして出力
socket scan create --report
```

## 主要コマンド

### メインコマンド

| コマンド | 説明 |
| --- | --- |
| `socket login` | APIトークンとデフォルト設定でSocket CLIをセットアップする |
| `socket scan create` | 新しいスキャンとレポートを作成する |
| `socket package score <ecosystem> <pkg>` | パッケージのSocketスコアを取得する |
| `socket fix` | 依存関係のCVEを修正する |
| `socket optimize` | `@socketregistry`のオーバーライドで依存関係を最適化する |
| `socket ci` | `socket scan create --report`のエイリアス（問題があればエラー終了） |
| `socket cdxgen` | SBOM生成のためにcdxgenを実行する |

### ラッパーコマンド

| コマンド | 説明 |
| --- | --- |
| `socket npm` | Socketセキュリティスキャン付きでnpmを実行する |
| `socket npx` | Socketセキュリティスキャン付きでnpxを実行する |
| `socket wrapper --enable` | Socket npm/npxラッパーを有効化する |
| `socket wrapper --disable` | Socket npm/npxラッパーを無効化する |

### CLI設定

| コマンド | 説明 |
| --- | --- |
| `socket config` | Socket CLIの設定を管理する |
| `socket install` | タブ補完をインストールする |
| `socket uninstall` | タブ補完をアンインストールする |

## グローバルオプション

| オプション | 説明 |
| --- | --- |
| `--dry-run` | アップロードせずに実行する |
| `--compact-header` | コンパクトなヘッダー形式を使用する |
| `--no-banner` | Socketバナーを非表示にする |
| `--help` | ヘルプを表示する |

## ユースケース

### パッケージ追加前にセキュリティスコアを確認する

```bash
socket package score npm some-package
```

新しいパッケージを追加する前に、そのパッケージのセキュリティリスクを評価する。

### 依存関係のCVEを自動修正する

```bash
socket fix
```

プロジェクトの依存関係に含まれる既知のCVE（脆弱性）を検出し、安全なバージョンへの更新を自動的に適用する。

### 依存関係を最適化する

```bash
socket optimize
```

`@socketregistry`のオーバーライドを利用して、依存関係をより安全で軽量な代替パッケージに置き換える。サプライチェーンの攻撃対象面を削減できる。

### npmラッパーでインストール時に自動スキャンする

```bash
# ラッパーを有効化
socket wrapper --enable

# 以降のnpm installでは自動的にセキュリティチェックが実行される
npm install some-package

# ラッパーを無効化する場合
socket wrapper --disable
```

npmラッパーを有効にすると、`npm install`や`npx`の実行時にSocketが自動的にパッケージのセキュリティチェックを行う。問題のあるパッケージのインストールを未然に防げる。

### CIでサプライチェーンリスクを検出する

```bash
socket ci
```

`socket scan create --report`のエイリアスで、PRごとに依存関係のセキュリティスキャンを実行し、問題があるとCIを失敗させる。GitHub Actionsなどに組み込んで継続的にサプライチェーンを監視できる。

## 参考リンク

- [Socket 公式サイト](https://socket.dev)
- [GitHub - socket-cli](https://github.com/SocketDev/socket-cli)
- [npm - @socketsecurity/cli](https://www.npmjs.com/package/@socketsecurity/cli)
