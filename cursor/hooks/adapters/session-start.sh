#!/usr/bin/env bash
# adapters/session-start.sh — session-start の Cursor アダプタ

set -euo pipefail

# WHY NOT: dirname を呼ばない（理由は hooks/README.md「外部コマンドを起動しない」）
_HOOK_DIR="${0%/*}"
[ "$_HOOK_DIR" = "$0" ] && _HOOK_DIR="."

LIB_DIR="$(cd "$_HOOK_DIR/../lib" && pwd)"
# shellcheck source=../lib/cursor-io.sh
source "$LIB_DIR/cursor-io.sh"

INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // .workspace.current_dir // empty')
CLAUDE_HOOK="$(cursor_io_dotfiles_dir)/claude/hooks/session-start/session-start.sh"

if [[ ! -x "$CLAUDE_HOOK" ]]; then
  echo "session-start adapter: hook not found: $CLAUDE_HOOK" >&2
  exit 0
fi

if [[ -n "$CWD" && -d "$CWD" ]]; then
  cd "$CWD" || true
fi

OUTPUT=$(bash "$CLAUDE_HOOK" 2>/dev/null || true)

if [[ -n "$OUTPUT" ]]; then
  jq -n --arg ctx "$OUTPUT" '{additional_context: $ctx}'
fi
exit 0
