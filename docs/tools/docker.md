# Docker Desktop

Dockerコンテナーの管理GUIアプリ。`docker` / `docker compose` コマンドのバックエンドとして動作する。**コマンドを使う前に必ずアプリを起動しておく必要がある。**

## インストール

```bash
brew install --cask docker
```

初回は `/usr/local/cli-plugins` ディレクトリが存在しない場合にエラーになるため、先に作成する。

```bash
sudo mkdir -p /usr/local/cli-plugins && brew install --cask docker
```

インストール後、Docker.appを起動してアカウント作成・初期設定を完了する。

## 基本的な使い方

```bash
# コンテナをバックグラウンドで起動
docker compose up -d

# コンテナを停止・削除
docker compose down

# 起動中のコンテナ一覧を確認
docker compose ps

# コンテナのログを確認
docker compose logs

# 特定コンテナのログをリアルタイムで流す
docker compose logs -f mix
```

## コンテナー内でコマンドを実行する

```bash
# コンテナ内でコマンドを1回実行
docker compose exec mix npm ci

# コンテナ内のシェルに入る（抜けるときは exit）
docker compose exec mix ash   # Alpine Linux系（mix など）
docker compose exec web bash  # Ubuntu/Debian系（web など）
```

## フロントエンド作業でよく使う操作

```bash
# 依存パッケージをインストール
docker compose exec mix npm ci

# 開発ビルドをウォッチモードで起動
docker compose exec mix npm run watch

# ビルドを1回だけ実行
docker compose exec mix npm run dev
```

## 環境変数の変更を反映する

`.env` を変更した後は、コンテナーを再起動しないと反映されない。

```bash
docker compose down && docker compose up -d
```

## 注意

- Docker Desktopアプリが起動していないと `docker` コマンドは使えない
- Docker Compose V1 (`docker-compose`) はメンテナンス終了。V2 (`docker compose`) を使う
- コンテナーのシェルに入る際、Alpine Linux系は `bash` が入っていないため `ash` を使う

## 参考リンク

- [Docker Desktop 公式ドキュメント](https://docs.docker.com/desktop/)
- [Docker Compose V1 から V2 への移行](https://docs.docker.com/compose/migrate/)
