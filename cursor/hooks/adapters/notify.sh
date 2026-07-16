#!/usr/bin/env bash
# adapters/notify.sh — notify.sh の Cursor アダプタ

set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/../lib" && pwd)"
# shellcheck source=../lib/cursor-io.sh
source "$LIB_DIR/cursor-io.sh"

INPUT=$(cat)
CLAUDE_HOOK="$(cursor_io_dotfiles_dir)/claude/hooks/notification/notify.sh"

if [[ ! -x "$CLAUDE_HOOK" ]]; then
  exit 0
fi

if ! command -v terminal-notifier &>/dev/null; then
  exit 0
fi

MESSAGE=$(printf '%s' "$INPUT" | jq -r '.message // .text // .content // empty')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // .workspace.current_dir // empty')

export CLAUDE_PROJECT_DIR="${CWD:-$(pwd)}"

CLAUDE_INPUT=$(
  jq -nc \
    --arg event "Stop" \
    --arg msg "$MESSAGE" \
    '{hook_event_name: $event, message: $msg}'
)

printf '%s' "$CLAUDE_INPUT" | bash "$CLAUDE_HOOK" 2>/dev/null || true
exit 0
