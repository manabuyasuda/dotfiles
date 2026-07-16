#!/usr/bin/env bash
# =============================================================================
# adapters/bash-guard.sh — bash-guard の Cursor アダプタ
# =============================================================================
# イベント : preToolUse（matcher: Shell。description は beforeShellExecution に無い）
# 本体     : claude/hooks/pre-tool-use/bash-guard.sh
# =============================================================================

set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/../lib" && pwd)"
# shellcheck source=../lib/cursor-io.sh
source "$LIB_DIR/cursor-io.sh"

INPUT=$(cat)

# Cursor の Shell フックでは description が空で届くことがある。高リスク操作だけ ask へ回す。
INPUT=$(cursor_io_shell_inject_description_fallback "$INPUT")

CLAUDE_HOOK="$(cursor_io_claude_pre_tool_use_hook bash-guard.sh)"

if [[ ! -x "$CLAUDE_HOOK" ]]; then
  cursor_io_fail_open_missing_hook "bash-guard adapter" "$CLAUDE_HOOK"
fi

CLAUDE_OUTPUT=$(
  printf '%s' "$INPUT" | cursor_io_shell_to_claude_json | bash "$CLAUDE_HOOK" 2>/dev/null || true
)

cursor_io_emit_claude_pre_tool_use "$CLAUDE_OUTPUT"
