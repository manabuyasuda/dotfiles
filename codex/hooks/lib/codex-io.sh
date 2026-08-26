#!/usr/bin/env bash
# =============================================================================
# codex-io.sh — Claude Code フック I/O と Codex フック I/O の変換ヘルパ
# =============================================================================
# Codex の wrap スクリプトから source する。判定ロジックは claude/hooks/ に置き、
# ここでは入出力形式の変換だけを担う。
# =============================================================================

_CODEX_IO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
_CURSOR_IO="${_CODEX_IO_LIB_DIR}/../../../cursor/hooks/lib/cursor-io.sh"
# shellcheck source=../../../cursor/hooks/lib/cursor-io.sh
source "$_CURSOR_IO"

codex_io_load_settings_env() {
  cursor_io_load_settings_env
}

# post-tool-use フック実行前にプロジェクト cwd へ移動する
# Why not: セッション環境ファイルの読み込みは cursor-io.sh と同じ理由で削除した。
codex_io_prepare_post_hook() {
  local input="$1"
  local cwd

  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
  if [[ -n "$cwd" && -d "$cwd" ]]; then
    cd "$cwd" || true
  fi
}

codex_io_emit_session_start() {
  local ctx="$1"
  if [[ -z "$ctx" ]]; then
    exit 0
  fi
  jq -n --arg ctx "$ctx" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $ctx
    }
  }'
  exit 0
}

# Claude PostToolUse の stdout は Codex と同じ hookSpecificOutput 形式のため、そのまま通す。
codex_io_emit_post_tool_use() {
  cursor_io_emit_claude_post_tool_use "$1"
}
