# dotfiles

macOS環境の設定ファイルを管理するリポジトリ。シンボリックリンク方式で、実ファイルをこのリポジトリ内に置き、ホームディレクトリからリンクを張る。

## 管理対象

| 領域 | ファイル | 説明 |
|------|---------|------|
| zsh | `.zshrc` | シェル設定（anyenv, direnv, PATH） |
| zsh | `.zprofile` | ログインシェル設定（Homebrew） |
| zsh | `.zshenv` | 全シェル共通の環境変数 |
| Git | `.gitconfig` | Git のグローバル設定 |
| Homebrew | `Brewfile` | インストールするパッケージ一覧 |
| Claude Code | `CLAUDE.md`, `settings.json`, `skills/` | グローバル指示、hooks、カスタムスキル |

## ディレクトリ構造

```
dotfiles/
├── setup.sh          # シンボリックリンク管理スクリプト
├── Brewfile           # Homebrew パッケージ一覧
├── zsh/
│   ├── .zshrc
│   ├── .zprofile
│   └── .zshenv
├── git/
│   └── .gitconfig
└── claude/
    ├── CLAUDE.md
    ├── settings.json
    └── skills/
```

## セットアップ

### 既存環境での初回セットアップ

```bash
git clone <repository-url> ~/Documents/MY/dotfiles
cd ~/Documents/MY/dotfiles
./setup.sh
```

`setup.sh` は既存ファイルを `~/.dotfiles_backup/` にバックアップしてからシンボリックリンクを作成する。何度実行しても安全（冪等）。

### 新しいマシンでのセットアップ

1. Homebrew をインストール
2. このリポジトリをクローン
3. Homebrew パッケージを復元: `brew bundle --file=~/Documents/MY/dotfiles/Brewfile`
4. セットアップスクリプトを実行: `./setup.sh`
5. anyenv と nodenv を手動でインストール:
   ```bash
   anyenv install --init
   anyenv install nodenv
   ```

## 運用

### 設定ファイルを編集した場合

シンボリックリンク経由なので、`~/.zshrc` などを直接編集すればリポジトリ内のファイルが更新される。

```bash
cd ~/Documents/MY/dotfiles
git diff
git add -A && git commit -m "update: 変更内容"
```

### Brewfile を更新する場合

```bash
brew bundle dump --file=~/Documents/MY/dotfiles/Brewfile --force
```

### Claude Code の設定を追加する場合

`claude/` ディレクトリ（`skills/`, `hooks/`, `agents/`, `rules/`）はディレクトリごとシンボリックリンクされているため、中にファイルを追加すると自動的にリポジトリに反映される。

`keybindings.json` など新しい個別ファイルを追加する場合は、`claude/` に作成してから `./setup.sh` を再実行する。

## 管理対象外のツール

以下はdotfilesでは管理していない。新しいマシンでは手動インストールが必要。

- **anyenv / nodenv** — `anyenv install --init` → `anyenv install nodenv`
- **gh extension** — `gh extension install <name>`
- **VS Code 拡張機能** — GitHubアカウント同期で管理

## 注意事項

- `.zprofile`のHomebrewパス(`/opt/homebrew`)はApple Silicon専用。Intel Macでは異なる
- `.gitconfig`が参照する`.gitignore_global`と`.stCommitMsg`は管理対象外
