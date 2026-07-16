#!/usr/bin/env bash
# =============================================================================
# cursor/statusline.sh — Cursor CLI statusline アダプタ
# =============================================================================
# Cursor CLI の StatusLinePayload を Claude Code 形式に変換し、
# claude/statusline.sh に委譲する。ctx_band キャッシュは claude 側が書く。
# =============================================================================

set -euo pipefail

_resolve_real_path() {
  local src="$1"
  if [[ -L "$src" ]]; then
    local target
    target=$(readlink "$src")
    if [[ "$target" != /* ]]; then
      target="$(cd "$(dirname "$src")" && pwd)/$target"
    fi
    printf '%s' "$target"
  else
    printf '%s' "$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"
  fi
}

REAL=$(_resolve_real_path "${BASH_SOURCE[0]}")
DOTFILES_DIR=$(cd "$(dirname "$REAL")/.." && pwd)
CLAUDE_STATUSLINE="$DOTFILES_DIR/claude/statusline.sh"

if [[ ! -x "$CLAUDE_STATUSLINE" ]]; then
  echo "cursor statusline: claude statusline not found: $CLAUDE_STATUSLINE" >&2
  exit 0
fi

if ! command -v jq &>/dev/null; then
  echo "jq not found" >&2
  exit 0
fi

input=$(cat)

printf '%s' "$input" | jq '{
  session_id: (.session_id // ""),
  model: {
    display_name: (.model.display_name // .model.id // "")
  },
  context_window: {
    context_window_size: (.context_window.context_window_size // null),
    used_percentage: (.context_window.used_percentage // null)
  },
  workspace: {
    current_dir: (.workspace.current_dir // .cwd // "")
  }
}' | bash "$CLAUDE_STATUSLINE"
