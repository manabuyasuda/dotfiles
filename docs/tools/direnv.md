# direnv

ディレクトリごとに環境変数を自動的にロード・アンロードするツール。`.envrc`ファイルに定義した環境変数が、そのディレクトリに`cd`すると自動で有効になり、離れると自動で無効になる。

## インストール

```bash
brew install direnv
```

シェルへのフック設定が必要（`~/.zshrc`に追記済み）。

## 基本的な使い方

```bash
# .envrc を作成・編集
echo 'export API_KEY=xxx' > .envrc

# .envrc を信頼して有効化（初回または変更後に必要）
direnv allow

# 現在のディレクトリの .envrc を無効化
direnv deny

# 現在のロード状態を表示
direnv status
```

## .envrc の書き方

```bash
# 環境変数の設定
export DATABASE_URL="postgresql://localhost/myapp"
export NODE_ENV="development"

# 他の .envrc を継承（親ディレクトリの設定を引き継ぐ）
source_up

# .env ファイルを読み込む
dotenv

# PATH にディレクトリを追加
PATH_add ./bin
PATH_add ./node_modules/.bin

# nodenv / anyenv のバージョンを固定
use node 20.0.0
```

## ユースケース

### プロジェクトごとに異なる環境変数を管理する

```bash
# プロジェクトルートに .envrc を作成
cat > .envrc <<'EOF'
export API_KEY=dev-key-xxx
export DATABASE_URL=postgresql://localhost/myapp_dev
EOF
direnv allow
```

`cd`するだけで環境変数が切り替わるため、複数プロジェクトの設定を手動で切り替える手間がなくなる。

### git worktreeで.envrcを引き継ぐ

このリポジトリの`worktree-create.sh`は、`.envrc`がgitignoreされている場合に新しいworktreeへ自動コピーする。コピー後は`direnv allow`が必要なため、クリップボードに自動でコマンドが用意される。

## 注意

`.envrc`に秘密情報を書く場合は`.gitignore`に追加する。

## 参考リンク

- [direnv 公式サイト](https://direnv.net/)
- [GitHub - direnv/direnv](https://github.com/direnv/direnv)
