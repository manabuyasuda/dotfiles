#!/usr/bin/env bash
# codex/config.toml の内容を ~/.codex/config.toml に反映する。
# Codex が書き込む [projects.*]、[hooks.*]、[tui.model_availability_nux] は既存ファイルから保持する。
# dotfiles の codex/config.toml が ~/.codex/config.toml の正とする。

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
SOURCE="$DOTFILES_DIR/codex/config.toml"
TARGET="$HOME/.codex/config.toml"

if [[ ! -f "$SOURCE" ]]; then
  echo "merge-codex-config: not found: $SOURCE" >&2
  exit 1
fi

mkdir -p "$(dirname "$TARGET")"

# 「最初の [projects.* からファイル末尾まで」をまとめて保持する方式は使わない。
# その範囲の後ろにある dotfiles 管理のセクション（[mcp_servers.*] 等）まで残り、
# dotfiles 側と重複して config.toml を読み込めなくなるため、セクション名で選ぶ。
# トップレベルのキー（/model が書く model・model_reasoning_effort）は保持しない。
extract_runtime_sections() {
  local file="$1"
  awk '
    /^\[/ { keep = ($0 ~ /^\[(projects\.|hooks\.|hooks\]|tui\.model_availability_nux\])/) }
    keep { print }
  ' "$file"
}

RUNTIME=""
if [[ -f "$TARGET" ]] && [[ ! -L "$TARGET" ]]; then
  RUNTIME=$(extract_runtime_sections "$TARGET")
elif [[ -f "$TARGET" ]] && [[ -L "$TARGET" ]]; then
  echo "merge-codex-config: ${TARGET} is a symlink; replacing with a regular file" >&2
  RUNTIME=$(extract_runtime_sections "$TARGET")
fi

{
  cat "$SOURCE"
  if [[ -n "$RUNTIME" ]]; then
    echo ""
    printf '%s\n' "$RUNTIME"
  fi
} >"${TARGET}.tmp"
mv "${TARGET}.tmp" "$TARGET"

if [[ -n "$RUNTIME" ]]; then
  echo "[MERGE] ${TARGET} (dotfiles + local projects/hooks/tui state preserved)"
else
  echo "[MERGE] ${TARGET} (dotfiles config applied)"
fi
