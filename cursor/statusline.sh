#!/usr/bin/env bash
# =============================================================================
# cursor/statusline.sh — Cursor CLI statusline アダプタ
# =============================================================================
# Cursor CLI の StatusLinePayload を Claude Code 形式に変換し、
# claude/statusline.sh に委譲する。ctx_band キャッシュは claude 側が書く。
# =============================================================================

set -euo pipefail

# WHY NOT: dirname / basename を使わない。statusline は Cursor の描画のたびに
# 実行されるため、1描画につき3プロセスの起動が積み上がる。プロセス起動は
# Endpoint Security（Jamf Protect）の検証対象になり、検証が滞るとカーネルが
# 拡張を強制終了して、その間すべてのアプリの操作が待たされてしまう。
# パス分解は bash のパラメータ展開で足りる（外部プロセスを起動しない）。
_resolve_real_path() {
  local src="$1" dir target
  dir="${src%/*}"
  [ "$dir" = "$src" ] && dir="."
  if [[ -L "$src" ]]; then
    target=$(readlink "$src")
    [[ "$target" != /* ]] && target="$(cd "$dir" && pwd)/$target"
    printf '%s' "$target"
  else
    printf '%s' "$(cd "$dir" && pwd)/${src##*/}"
  fi
}

REAL=$(_resolve_real_path "${BASH_SOURCE[0]}")
REAL_DIR="${REAL%/*}"
DOTFILES_DIR=$(cd "$REAL_DIR/.." && pwd)
CLAUDE_STATUSLINE="$DOTFILES_DIR/claude/statusline.sh"

if [[ ! -x "$CLAUDE_STATUSLINE" ]]; then
  echo "cursor statusline: claude statusline not found: $CLAUDE_STATUSLINE" >&2
  exit 0
fi

if ! command -v jq &>/dev/null; then
  echo "jq not found" >&2
  exit 0
fi

# WHY NOT: $(cat) で受け取らない。cat の起動1回ぶんを、bash のリダイレクトで置き換える。
input=$(</dev/stdin)

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
