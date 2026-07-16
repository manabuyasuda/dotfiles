#!/usr/bin/env bash
# =============================================================================
# adapters/dangerous-guard.sh — dangerous-guard の Cursor アダプタ
# =============================================================================
# イベント : beforeShellExecution
# 本体     : claude/hooks/pre-tool-use/dangerous-guard.sh
# =============================================================================

set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/../lib" && pwd)"
# shellcheck source=../lib/cursor-io.sh
source "$LIB_DIR/cursor-io.sh"

INPUT=$(cat)
CLAUDE_HOOK="$(cursor_io_claude_pre_tool_use_hook dangerous-guard.sh)"

if [[ ! -x "$CLAUDE_HOOK" ]]; then
  cursor_io_fail_open_missing_hook "dangerous-guard adapter" "$CLAUDE_HOOK"
fi

CLAUDE_OUTPUT=$(
  printf '%s' "$INPUT" | cursor_io_shell_to_claude_json | bash "$CLAUDE_HOOK" 2>/dev/null || true
)

cursor_io_emit_claude_pre_tool_use "$CLAUDE_OUTPUT"
