# ngrok

ローカルサーバーを外部からアクセス可能な URL として公開するトンネリングツール。Webhook の受信テストや、モバイル端末・外部サービスからのローカル開発環境への接続に使う。

## インストール

```bash
brew install --cask ngrok
```

初回は[ngrok.com](https://ngrok.com)でアカウント作成後、認証トークンを設定する。

```bash
ngrok config add-authtoken <token>
```

## 基本的な使い方

```bash
# ローカルの 3000 番ポートを公開する
ngrok http 3000

# HTTPS のみで公開する
ngrok http --scheme https 3000

# カスタムサブドメインを使う（有料プラン）
ngrok http --subdomain myapp 3000

# TCP ポートを公開する
ngrok tcp 22
```

実行後に表示される`Forwarding`のURL（例: `https://xxxx.ngrok.io`）から外部アクセスできる。

## 主要オプション

| オプション | 説明 |
|---|---|
| `--scheme <scheme>` | プロトコルを指定する（`http` / `https`） |
| `--subdomain <name>` | サブドメインを指定する（有料プラン） |
| `--auth <user:pass>` | Basic 認証を設定する |
| `--host-header <host>` | リクエストの Host ヘッダーを書き換える |
| `--inspect` | Web インスペクター UI を有効にする（デフォルト: `true`） |

## Web インスペクター

ngrok起動中は`http://localhost:4040`で通信内容を確認できる。受信したリクエストの詳細（ヘッダー・ボディ）やレスポンスを確認したり、同じリクエストを再送したりできる。

## ユースケース

### Webhook をローカルで受け取る

```bash
ngrok http 3000
```

GitHub・Stripe・LINEなどのWebhook URLにngrokのURLを設定することで、ローカル開発サーバーで直接受け取ってデバッグできる。

### スマートフォンでローカル環境を確認する

```bash
ngrok http 3000
```

同一Wi-Fiでなくても、発行されたURLをスマートフォンで開くだけでローカルサーバーにアクセスできる。レスポンシブデザインの実機確認に使える。

## 注意

- 無料プランではトンネルのURLが起動のたびに変わる
- 公開URLは誰でもアクセスできるため、機密情報を含む環境での使用は注意

## 参考リンク

- [ngrok 公式ドキュメント](https://ngrok.com/docs)
- [ngrok ダッシュボード](https://dashboard.ngrok.com)
