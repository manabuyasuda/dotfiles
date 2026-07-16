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
  "mise/config.toml:.config/mise/config.toml"
  "claude/CLAUDE.md:.claude/CLAUDE.md"
  "claude/settings.json:.claude/settings.json"
  "claude/keybindings.json:.claude/keybindings.json"
  "claude/statusline.sh:.claude/statusline.sh"
  "cursor/statusline.sh:.cursor/statusline.sh"
  "claude/skills:.claude/skills"
  "claude/hooks:.claude/hooks"
  "claude/agents:.claude/agents"
  "claude/agents:.cursor/agents"
  "claude/docs:.claude/docs"
  "claude/rules:.claude/rules"
  "cursor/rules:.cursor/rules"
  "cursor/hooks.json:.cursor/hooks.json"
  "cursor/hooks:.cursor/hooks"
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

# === Cursor CLI permissions（shared → cli-config.json）===
echo ""
echo "--- Cursor CLI permissions ---"

SYNC_CURSOR_PERMS="$DOTFILES_DIR/scripts/sync-cursor-cli-permissions.sh"
MERGE_CURSOR_CONFIG="$DOTFILES_DIR/scripts/merge-cursor-cli-config.sh"
if [[ -x "$SYNC_CURSOR_PERMS" ]] && [[ -x "$MERGE_CURSOR_CONFIG" ]]; then
  "$SYNC_CURSOR_PERMS"
  "$MERGE_CURSOR_CONFIG"
else
  echo "[SKIP] sync/merge スクリプトが見つかりません"
fi

# === dotfiles プロジェクトの .claude/settings.local.json ===
echo ""
echo "--- dotfiles project settings.local.json ---"

DOTFILES_PROJECT_SETTINGS="$DOTFILES_DIR/.claude/settings.local.json"
if [[ -f "$DOTFILES_PROJECT_SETTINGS" ]]; then
  echo "[OK] 作成済み: $DOTFILES_PROJECT_SETTINGS"
else
  mkdir -p "$DOTFILES_DIR/.claude"
  cat > "$DOTFILES_PROJECT_SETTINGS" << 'SETTINGS_EOF'
{
  "permissions": {
    "allow": []
  }
}
SETTINGS_EOF
  echo "[CREATE] $DOTFILES_PROJECT_SETTINGS"
fi

# === gh 拡張機能 ===
echo ""
echo "--- gh extensions ---"

if ! command -v gh &>/dev/null; then
  echo "[SKIP] gh が見つかりません"
else
  GH_EXTENSIONS_FILE="$DOTFILES_DIR/gh/extensions"
  if [[ -f "$GH_EXTENSIONS_FILE" ]]; then
    installed_extensions="$(gh extension list 2>/dev/null || true)"
    while IFS= read -r line || [[ -n "$line" ]]; do
      # 空行・コメント行をスキップ
      [[ -z "$line" || "$line" == \#* ]] && continue
      if echo "$installed_extensions" | grep -q "$line"; then
        echo "[OK] インストール済み: $line"
      else
        echo "[INSTALL] $line"
        gh extension install "$line"
      fi
    done < "$GH_EXTENSIONS_FILE"
  else
    echo "[SKIP] gh/extensions ファイルが見つかりません"
  fi
fi

# === lefthook pre-commit フック ===
echo ""
echo "--- lefthook pre-commit hook ---"

# ~/.npmrc に ignore-scripts=true がある環境では `npm ci` 時に prepare
# （lefthook install）が走らず pre-commit フックが配置されない。ここで明示的に配置する。
# lefthook 未導入（npm ci より前）の場合はスキップし、再実行を促す。
LEFTHOOK_BIN="$DOTFILES_DIR/node_modules/.bin/lefthook"
if [[ -x "$LEFTHOOK_BIN" ]]; then
  if "$LEFTHOOK_BIN" install >/dev/null 2>&1; then
    echo "[OK] pre-commit フックを配置しました"
  else
    echo "[WARN] lefthook install に失敗しました"
  fi
else
  echo "[SKIP] lefthook 未導入（npm ci 後に setup.sh を再実行するか 'npx lefthook install' を実行）"
fi

# === bashlex venv (verify-package-install hook 用) ===
# pre-tool-use/verify-package-install.sh が install コマンドの誤検知を避けるため
# Python の bashlex で AST 解析する。PEP 668 環境を避けて専用の venv に隔離する。
# venv が無ければ作成し、bashlex が未導入なら入れる。両方揃っていればスキップする。
# python3 が無い環境ではフォールバック（bash 単独経路）に任せて SKIP する。
echo ""
echo "--- bashlex venv ---"

BASHLEX_VENV="$HOME/.local/share/bashlex-venv"
BASHLEX_PY="$BASHLEX_VENV/bin/python3"
if ! command -v python3 &>/dev/null; then
  echo "[SKIP] python3 が見つかりません（hook は bash フォールバック経路で動作します）"
elif [[ -x "$BASHLEX_PY" ]] && "$BASHLEX_PY" -c 'import bashlex' &>/dev/null; then
  echo "[OK] 導入済み: $BASHLEX_VENV"
else
  if [[ ! -x "$BASHLEX_PY" ]]; then
    echo "[CREATE] $BASHLEX_VENV"
    python3 -m venv "$BASHLEX_VENV"
  fi
  echo "[INSTALL] bashlex"
  "$BASHLEX_VENV/bin/pip" install --quiet bashlex
fi

echo ""
echo "=== 完了 ==="

if [[ -d "$BACKUP_DIR" ]]; then
  echo "バックアップ先: $BACKUP_DIR"
fi
