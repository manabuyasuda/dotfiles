#!/usr/bin/env bash
# adapters/typecheck-edited-files.sh — stop/typecheck-edited-files.sh の Cursor アダプタ（stop）

set -euo pipefail

# WHY NOT: dirname を呼ばない（理由は hooks/README.md「外部コマンドを起動しない」）
_HOOK_DIR="${0%/*}"
[ "$_HOOK_DIR" = "$0" ] && _HOOK_DIR="."

LIB_DIR="$(cd "$_HOOK_DIR/../lib" && pwd)"
# shellcheck source=../lib/cursor-io.sh
source "$LIB_DIR/cursor-io.sh"

INPUT=$(cat)
CLAUDE_HOOK="$(cursor_io_claude_stop_hook typecheck-edited-files.sh)"

if [[ ! -x "$CLAUDE_HOOK" ]]; then
  echo "typecheck-edited-files adapter: hook not found: $CLAUDE_HOOK" >&2
  exit 0
fi

CLAUDE_OUTPUT=$(
  printf '%s' "$INPUT" | cursor_io_stop_to_claude_json | bash "$CLAUDE_HOOK" 2>/dev/null || true
)

cursor_io_emit_claude_stop "$CLAUDE_OUTPUT"
