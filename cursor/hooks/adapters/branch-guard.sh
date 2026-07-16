#!/usr/bin/env bash
# =============================================================================
# adapters/branch-guard.sh — branch-guard の Cursor アダプタ
# =============================================================================
# イベント : preToolUse（matcher: Write、file-protect の後に実行）
# 本体     : claude/hooks/pre-tool-use/branch-guard.sh
# =============================================================================

set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/../lib" && pwd)"
# shellcheck source=../lib/cursor-io.sh
source "$LIB_DIR/cursor-io.sh"

INPUT=$(cat)
CLAUDE_HOOK="$(cursor_io_claude_pre_tool_use_hook branch-guard.sh)"

if [[ ! -x "$CLAUDE_HOOK" ]]; then
  cursor_io_fail_open_missing_hook "branch-guard adapter" "$CLAUDE_HOOK"
fi

# branch-guard は deny 時に exit 2 するが stdout に JSON を出す
CLAUDE_OUTPUT=$(
  printf '%s' "$INPUT" | cursor_io_write_to_claude_json | bash "$CLAUDE_HOOK" 2>/dev/null || true
)

cursor_io_emit_claude_pre_tool_use "$CLAUDE_OUTPUT"
