# Docker（OrbStack）

Dockerコンテナーを動かすランタイムとしてOrbStackを使う。OrbStackはDocker Desktopの軽量な代替で、`docker` / `docker compose` コマンドのバックエンドとして動作する。`docker` CLIは `~/.orbstack/bin` に置かれ、OrbStackの初回起動で作成される。

> Docker DesktopからOrbStackへ移行済み。Brewfileは `cask "docker"` を削除し `cask "orbstack"` に一本化している。`~/.orbstack/bin` は `zsh/.zshenv` でPATHに追加済み。

## 導入手順（本格導入するとき）

業務利用では会社が契約しているOrbStackのシートを使う。次の順に進めれば、`docker` コマンドが使える状態になる。

1. OrbStackがインストール済みか確認する。未導入なら入れる（Brewfile経由でも入る）。

   ```bash
   brew list --cask | grep -q orbstack && echo installed || brew install --cask orbstack
   ```

2. OrbStackアプリを起動する。初回起動でセットアップが走り、`~/.orbstack/bin` に `docker` などのCLIが作成される。

   ```bash
   open -a OrbStack
   ```

3. 業務利用のライセンスを受けるため、会社アカウント（割り当て元のメールアドレス）でサインインする。会社がOrgでシートを管理しているため、サインインするとシートが割り当てられる。シート枠の残数や課金区分が不明なときは、OrbStackのOrg管理者に確認する。

4. PATHを反映する。`~/.orbstack/bin` は `zsh/.zshenv` でPATHに追加済みなので、シェルを読み込み直すだけでよい。

   ```bash
   exec $SHELL -l
   ```

5. `docker` がOrbStack由来になっているか確認する。

   ```bash
   which docker        # ~/.orbstack/bin/docker を指せばOK
   docker version      # Server 側に OrbStack が表示されれば成功
   docker run --rm hello-world
   ```

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

- OrbStackが起動していないと `docker` コマンドは使えない。OrbStackは軽量で起動も速く、ログイン項目に登録すれば自動起動にできる
- Docker Compose V1 (`docker-compose`) はメンテナンス終了。V2 (`docker compose`) を使う
- コンテナーのシェルに入る際、Alpine Linux系は `bash` が入っていないため `ash` を使う

## 参考リンク

- [OrbStack 公式ドキュメント](https://docs.orbstack.dev/)
- [OrbStack のライセンス・料金](https://orbstack.dev/pricing)
- [Docker Compose V1 から V2 への移行](https://docs.docker.com/compose/migrate/)
