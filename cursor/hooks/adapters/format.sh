#!/usr/bin/env bash
# adapters/format.sh — format.sh の Cursor アダプタ

set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/../lib" && pwd)"
# shellcheck source=../lib/cursor-io.sh
source "$LIB_DIR/cursor-io.sh"

INPUT=$(cat)
CLAUDE_HOOK="$(cursor_io_claude_post_tool_use_hook format.sh)"

if [[ ! -x "$CLAUDE_HOOK" ]]; then
  echo "format adapter: hook not found: $CLAUDE_HOOK" >&2
  exit 0
fi

cursor_io_prepare_post_hook "$INPUT"

CLAUDE_OUTPUT=$(
  printf '%s' "$INPUT" | cursor_io_write_to_claude_json | bash "$CLAUDE_HOOK" 2>/dev/null || true
)

cursor_io_emit_claude_post_tool_use "$CLAUDE_OUTPUT"
