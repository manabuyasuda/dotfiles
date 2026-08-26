#!/usr/bin/env bash
# wrap/stop.sh — claude/hooks/stop/* の Codex ラッパ
# Codex の Stop は入力（session_id / cwd / stop_hook_active）も出力（decision: block）も
# Claude Code と同じ形式のため、変換せずにそのまま渡す。

set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/../lib" && pwd)"
# shellcheck source=../lib/codex-io.sh
source "$LIB_DIR/codex-io.sh"

HOOK_NAME="${1:-}"
if [[ -z "$HOOK_NAME" ]]; then
  echo "stop wrap: hook name required" >&2
  exit 0
fi

CLAUDE_HOOK="$(cursor_io_claude_stop_hook "$HOOK_NAME")"
if [[ ! -f "$CLAUDE_HOOK" ]]; then
  echo "stop wrap: hook not found: $CLAUDE_HOOK" >&2
  exit 0
fi

INPUT=$(cat)
codex_io_prepare_post_hook "$INPUT"

printf '%s' "$INPUT" | bash "$CLAUDE_HOOK" 2>/dev/null || true
exit 0
