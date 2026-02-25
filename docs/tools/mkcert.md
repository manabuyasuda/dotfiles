# mkcert

ローカル開発用の信頼された HTTPS 証明書を発行するツール。自己署名証明書とは異なり、ブラウザの警告なしに HTTPS でローカルサーバーを動かせる。

## インストール

```bash
brew install mkcert nss  # nss は Firefox 向け
```

## 初期設定（初回のみ）

```bash
# ローカル CA（認証局）をシステムに登録する
mkcert -install
```

これにより、mkcertが発行する証明書がシステム・ブラウザから信頼される。

## 基本的な使い方

```bash
# localhost 向けの証明書を発行
mkcert localhost

# 複数ドメイン・IP に対応した証明書を発行
mkcert localhost 127.0.0.1 ::1

# カスタムドメイン向けの証明書を発行
mkcert myapp.local "*.myapp.local"

# CA のルート証明書の場所を確認
mkcert -CAROOT
```

実行後、カレントディレクトリに`*.pem`ファイルが生成される。

## 生成されるファイル

| ファイル | 説明 |
|---|---|
| `localhost.pem` | 証明書（`cert` として使う） |
| `localhost-key.pem` | 秘密鍵（`key` として使う） |

## ユースケース

### Next.jsでローカルHTTPSを使う

```bash
mkcert localhost
```

```js
// next.config.js（カスタムサーバーの場合）
const https = require('https')
const fs = require('fs')

https.createServer({
  key: fs.readFileSync('localhost-key.pem'),
  cert: fs.readFileSync('localhost.pem'),
}, app).listen(3000)
```

### ngrokなしにローカルでHTTPSを確認する

OAuthやService WorkerなどHTTPSが必須な機能をローカルで開発するときに使う。

## 注意

- 生成した証明書・秘密鍵は `.gitignore` に追加する
- `mkcert -install`で登録したローカルCAは開発マシン固有のもの。他のマシンでは再セットアップが必要

## 参考リンク

- [GitHub - FiloSottile/mkcert](https://github.com/FiloSottile/mkcert)
