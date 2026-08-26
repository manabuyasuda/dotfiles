#!/usr/bin/env bash
# adapters/track-edited-files.sh — track-edited-files.sh の Cursor アダプタ（postToolUse）

set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/../lib" && pwd)"
# shellcheck source=../lib/cursor-io.sh
source "$LIB_DIR/cursor-io.sh"

INPUT=$(cat)
CLAUDE_HOOK="$(cursor_io_claude_post_tool_use_hook track-edited-files.sh)"

if [[ ! -x "$CLAUDE_HOOK" ]]; then
  echo "track-edited-files adapter: hook not found: $CLAUDE_HOOK" >&2
  exit 0
fi

# 記録するだけで出力は無い
printf '%s' "$INPUT" | cursor_io_write_to_claude_json | bash "$CLAUDE_HOOK" >/dev/null 2>&1 || true
exit 0
