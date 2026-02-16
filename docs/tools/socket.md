# Socket

npm パッケージのサプライチェーンリスクを検出するセキュリティツール。悪意のあるパッケージ、タイポスクワッティング、既知の脆弱性を識別する。

## インストール

```bash
npm install -g @socketsecurity/cli
```

`nodenv/default-packages` で自動インストールされる。

## 基本的な使い方

```bash
# Socket CLI のセットアップ（API トークンの設定）
socket login

# プロジェクトのスキャンを作成
socket scan create

# パッケージのセキュリティスコアを確認
socket package score npm lodash

# npm ラッパーを有効化（インストール時に自動スキャン）
socket wrapper --enable

# スキャン結果をレポートとして出力
socket scan create --report
```

## ユースケース

### パッケージ追加前にセキュリティスコアを確認する

```bash
socket package score npm some-package
```

新しいパッケージを追加する前に、そのパッケージのセキュリティリスクを評価する。

### CI でサプライチェーンリスクを検出する

```bash
socket ci
```

`socket scan create --report` のエイリアスで、PR ごとに依存関係のセキュリティスキャンを実行し、問題があると CI を失敗させる。

### npm install をセキュリティスキャン付きで実行する

```bash
socket wrapper --enable
npm install
```

npm ラッパーを有効にすると、`npm install` 実行時に自動的にパッケージのセキュリティチェックが行われる。

## 参考リンク

- [Socket 公式サイト](https://socket.dev)
- [GitHub - socket-cli](https://github.com/SocketDev/socket-cli)
- [npm - @socketsecurity/cli](https://www.npmjs.com/package/@socketsecurity/cli)
