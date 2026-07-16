#!/usr/bin/env bash
# adapters/mermaid-guard-post.sh — mermaid-guard (post) の Cursor アダプタ
#
# Claude PostToolUse の deny を Cursor postToolUse の additional_context に変換する。

set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/../lib" && pwd)"
# shellcheck source=../lib/cursor-io.sh
source "$LIB_DIR/cursor-io.sh"

INPUT=$(cat)
CLAUDE_HOOK="$(cursor_io_claude_post_tool_use_hook mermaid-guard.sh)"

if [[ ! -x "$CLAUDE_HOOK" ]]; then
  cursor_io_fail_open_missing_hook "mermaid-guard-post adapter" "$CLAUDE_HOOK"
fi

CLAUDE_OUTPUT=$(
  printf '%s' "$INPUT" | cursor_io_write_to_claude_json | bash "$CLAUDE_HOOK" 2>/dev/null || true
)

cursor_io_emit_claude_post_tool_use "$CLAUDE_OUTPUT"
