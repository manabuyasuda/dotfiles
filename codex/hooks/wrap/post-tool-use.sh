#!/usr/bin/env bash
# wrap/post-tool-use.sh — claude/hooks/post-tool-use/* の Codex ラッパ

set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/../lib" && pwd)"
# shellcheck source=../lib/codex-io.sh
source "$LIB_DIR/codex-io.sh"

HOOK_NAME="${1:-}"
if [[ -z "$HOOK_NAME" ]]; then
  echo "post-tool-use wrap: hook name required" >&2
  exit 0
fi

CLAUDE_HOOK="$(cursor_io_claude_post_tool_use_hook "$HOOK_NAME")"
if [[ ! -f "$CLAUDE_HOOK" ]]; then
  echo "post-tool-use wrap: hook not found: $CLAUDE_HOOK" >&2
  exit 0
fi

INPUT=$(cat)
codex_io_prepare_post_hook "$INPUT"

CLAUDE_OUTPUT=$(
  printf '%s' "$INPUT" | cursor_io_write_to_claude_json | bash "$CLAUDE_HOOK" 2>/dev/null || true
)

codex_io_emit_post_tool_use "$CLAUDE_OUTPUT"
