#!/usr/bin/env bash
# adapters/session-start.sh — session-start の Cursor アダプタ

set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/../lib" && pwd)"
# shellcheck source=../lib/cursor-io.sh
source "$LIB_DIR/cursor-io.sh"

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // .workspace.current_dir // empty')
CLAUDE_HOOK="$(cursor_io_dotfiles_dir)/claude/hooks/session-start/session-start.sh"

if [[ ! -x "$CLAUDE_HOOK" ]]; then
  echo "session-start adapter: hook not found: $CLAUDE_HOOK" >&2
  exit 0
fi

if [[ -n "$SESSION_ID" ]]; then
  ENV_FILE="$(cursor_io_session_env_file "$SESSION_ID")"
  mkdir -p "$(dirname "$ENV_FILE")"
  : >"$ENV_FILE"
  export CLAUDE_ENV_FILE="$ENV_FILE"
fi

if [[ -n "$CWD" && -d "$CWD" ]]; then
  cd "$CWD" || true
fi

OUTPUT=$(bash "$CLAUDE_HOOK" 2>/dev/null || true)

if [[ -n "$OUTPUT" ]]; then
  jq -n --arg ctx "$OUTPUT" '{additional_context: $ctx}'
fi
exit 0
