#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

# シンボリックリンクのマッピング定義
# 形式: "リポジトリ相対パス:ホーム相対パス"
SYMLINKS=(
  "zsh/.zshrc:.zshrc"
  "zsh/.zprofile:.zprofile"
  "zsh/.zshenv:.zshenv"
  "git/.gitconfig:.gitconfig"
  "claude/CLAUDE.md:.claude/CLAUDE.md"
  "claude/settings.json:.claude/settings.json"
  "claude/keybindings.json:.claude/keybindings.json"
  "claude/skills:.claude/skills"
  "claude/hooks:.claude/hooks"
  "claude/agents:.claude/agents"
  "claude/rules:.claude/rules"
)

backup_and_link() {
  local src="$DOTFILES_DIR/$1"
  # 第3引数があれば絶対パスとして使用、なければ $HOME 相対パス
  local dst="${3:-$HOME/$2}"
  local dst_dir
  dst_dir="$(dirname "$dst")"

  # ソースが存在しなければスキップ
  if [[ ! -e "$src" ]]; then
    echo "[SKIP] ソースが存在しません: $src"
    return
  fi

  # 親ディレクトリを作成
  if [[ ! -d "$dst_dir" ]]; then
    echo "[MKDIR] $dst_dir"
    mkdir -p "$dst_dir"
  fi

  # 既に正しいリンクならスキップ（冪等性）
  if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]]; then
    echo "[OK] リンク済み: $dst"
    return
  fi

  # 既存ファイルをバックアップ
  if [[ -e "$dst" ]] || [[ -L "$dst" ]]; then
    mkdir -p "$BACKUP_DIR"
    echo "[BACKUP] $dst -> $BACKUP_DIR/"
    mv "$dst" "$BACKUP_DIR/"
  fi

  # シンボリックリンクを作成
  ln -s "$src" "$dst"
  echo "[LINK] $dst -> $src"
}

echo "=== dotfiles setup ==="
echo "リポジトリ: $DOTFILES_DIR"
echo ""

for mapping in "${SYMLINKS[@]}"; do
  src="${mapping%%:*}"
  dst="${mapping##*:}"
  backup_and_link "$src" "$dst"
done

# === nodenv プラグイン ===
echo ""
echo "--- nodenv-default-packages ---"

NODENV_ROOT="${NODENV_ROOT:-$(nodenv root 2>/dev/null)}"

if [[ -z "$NODENV_ROOT" ]]; then
  echo "[SKIP] nodenv が見つかりません"
else
  # nodenv-default-packages プラグインのインストール
  PLUGIN_DIR="$NODENV_ROOT/plugins/nodenv-default-packages"
  if [[ -d "$PLUGIN_DIR" ]]; then
    echo "[OK] nodenv-default-packages インストール済み"
  else
    echo "[INSTALL] nodenv-default-packages"
    git clone https://github.com/nodenv/nodenv-default-packages.git "$PLUGIN_DIR"
  fi

  # default-packages のシンボリックリンク
  backup_and_link "nodenv/default-packages" "" "$NODENV_ROOT/default-packages"
fi

echo ""
echo "=== 完了 ==="

if [[ -d "$BACKUP_DIR" ]]; then
  echo "バックアップ先: $BACKUP_DIR"
fi
