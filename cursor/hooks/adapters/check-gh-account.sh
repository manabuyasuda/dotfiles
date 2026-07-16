#!/usr/bin/env bash
# adapters/check-gh-account.sh — check-gh-account の Cursor アダプタ
#
# Claude 本体は stderr + exit 2 で警告する。Cursor では permission: deny に変換する。

set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/../lib" && pwd)"
# shellcheck source=../lib/cursor-io.sh
source "$LIB_DIR/cursor-io.sh"

cursor_io_load_settings_env

INPUT=$(cat)
CLAUDE_HOOK="$(cursor_io_claude_pre_tool_use_hook check-gh-account.sh)"

if [[ ! -x "$CLAUDE_HOOK" ]]; then
  cursor_io_fail_open_missing_hook "check-gh-account adapter" "$CLAUDE_HOOK"
fi

stderr_file=$(mktemp)
trap 'rm -f "$stderr_file"' EXIT

exit_code=0
CLAUDE_OUTPUT=$(
  printf '%s' "$INPUT" | cursor_io_shell_to_claude_json | bash "$CLAUDE_HOOK" 2>"$stderr_file"
) || exit_code=$?

if [[ "$exit_code" -eq 2 ]] && [[ -s "$stderr_file" ]]; then
  msg=$(cat "$stderr_file")
  jq -n --arg um "$msg" --arg am "$msg" \
    '{permission: "deny", user_message: $um, agent_message: $am}'
  exit 0
fi

cursor_io_emit_claude_pre_tool_use "$CLAUDE_OUTPUT"
