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

# Cursor の Shell フックでは description が空で届くことがある（beforeShellExecution は非対応、
# preToolUse でもバージョンによって省略される）。空のときは deny せず ask へ回すプレースホルダを入れる。
INPUT=$(
  printf '%s' "$INPUT" | jq '
    (.tool_input.description // .description // "") as $d |
    if $d == "" then
      (if .tool_input then
        .tool_input.description = "目的:エージェントのdescriptionがフックに届かないため 影響:下記コマンドの実行 許可:内容確認後 拒否:不審または意図と異なる操作"
      else
        .description = "目的:エージェントのdescriptionがフックに届かないため 影響:下記コマンドの実行 許可:内容確認後 拒否:不審または意図と異なる操作"
      end)
    else . end
  '
)

CLAUDE_HOOK="$(cursor_io_claude_pre_tool_use_hook bash-guard.sh)"

if [[ ! -x "$CLAUDE_HOOK" ]]; then
  cursor_io_fail_open_missing_hook "bash-guard adapter" "$CLAUDE_HOOK"
fi

CLAUDE_OUTPUT=$(
  printf '%s' "$INPUT" | cursor_io_shell_to_claude_json | bash "$CLAUDE_HOOK" 2>/dev/null || true
)

cursor_io_emit_claude_pre_tool_use "$CLAUDE_OUTPUT"
