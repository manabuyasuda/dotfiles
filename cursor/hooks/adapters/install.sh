#!/usr/bin/env bash
# adapters/install.sh — install.sh の Cursor アダプタ

set -euo pipefail

# WHY NOT: dirname を呼ばない（理由は hooks/README.md「外部コマンドを起動しない」）
_HOOK_DIR="${0%/*}"
[ "$_HOOK_DIR" = "$0" ] && _HOOK_DIR="."

LIB_DIR="$(cd "$_HOOK_DIR/../lib" && pwd)"
# shellcheck source=../lib/cursor-io.sh
source "$LIB_DIR/cursor-io.sh"

INPUT=$(cat)
CLAUDE_HOOK="$(cursor_io_claude_post_tool_use_hook install.sh)"

if [[ ! -x "$CLAUDE_HOOK" ]]; then
  exit 0
fi

cursor_io_prepare_post_hook "$INPUT"

CLAUDE_OUTPUT=$(
  printf '%s' "$INPUT" | cursor_io_write_to_claude_json | bash "$CLAUDE_HOOK" 2>/dev/null || true
)

cursor_io_emit_claude_post_tool_use "$CLAUDE_OUTPUT"
