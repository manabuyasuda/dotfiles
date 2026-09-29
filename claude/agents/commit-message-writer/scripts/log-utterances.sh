#!/usr/bin/env bash
# Print user/assistant utterances from the running agent's work log.
#
# Usage:
#   log-utterances.sh [--cwd <repo root>] [--since <unix_ts>]
#
# Searches Claude Code, Codex and Cursor log stores and prints whatever it
# finds, so the caller does not need to know which agent it runs on.
# Output: "<source> [user|assistant] <text>" per line, full text.

set -euo pipefail

CWD=""
SINCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd) CWD="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$CWD" ]] || CWD="$(git rev-parse --show-toplevel)"

# find(1) has no portable epoch predicate, so compare mtimes with a marker file.
newer_args=()
if [[ -n "$SINCE" ]]; then
  marker="$(mktemp)"
  trap 'rm -f "$marker"' EXIT
  touch -t "$(date -r "$SINCE" '+%Y%m%d%H%M.%S' 2>/dev/null \
    || date -d "@$SINCE" '+%Y%m%d%H%M.%S')" "$marker"
  newer_args=(-newer "$marker")
fi

claude_logs() {
  local dir="${CLAUDE_PROJECTS:-$HOME/.claude/projects}/$(printf '%s' "$CWD" | tr '/.' '--')"
  [[ -d "$dir" ]] || return 0
  find "$dir" -type f -name '*.jsonl' "${newer_args[@]}" 2>/dev/null | while read -r f; do
    jq -r '
      select(.type=="user" or .type=="assistant")
      | (.message.content
         | if type=="string" then . else ([.[]? | select(.type=="text") | .text] | join("\n")) end) as $t
      | select(($t|length) > 0 and ($t|startswith("<")|not))
      | "claude [\(.type)] \($t)"
    ' "$f" 2>/dev/null
  done
}

codex_logs() {
  local dir="${CODEX_HOME:-$HOME/.codex}/sessions"
  [[ -d "$dir" ]] || return 0
  find "$dir" -type f -name 'rollout-*.jsonl' "${newer_args[@]}" 2>/dev/null | while read -r f; do
    jq -e --arg cwd "$CWD" 'select(.type=="session_meta") | .payload.cwd == $cwd' "$f" >/dev/null 2>&1 || continue
    jq -r '
      select(.type=="response_item" and .payload.type=="message")
      | (.payload.content // [] | map(.text // "") | join("\n")) as $t
      | select(($t|length) > 0 and ($t|startswith("<")|not))
      | "codex [\(.payload.role)] \($t)"
    ' "$f" 2>/dev/null
  done
}

cursor_logs() {
  local hash
  hash="$(printf '%s' "$CWD" | { md5 -q 2>/dev/null || md5sum | cut -d' ' -f1; })"
  local dir="${CURSOR_CHATS:-$HOME/.cursor/chats}/$hash"
  [[ -d "$dir" ]] || return 0
  find "$dir" -type f -name 'store.db' "${newer_args[@]}" 2>/dev/null | while read -r f; do
    sqlite3 "$f" "
      WITH m AS (
        SELECT rowid AS r, CAST(data AS TEXT) AS t FROM blobs
        WHERE json_valid(CAST(data AS TEXT))
      )
      SELECT msg FROM (
        SELECT r, 'cursor [user] ' ||
          substr(rest, 1, instr(rest, '</user_query>') - 1) AS msg
        FROM (
          SELECT r, substr(x, instr(x, '<user_query>') + 12) AS rest FROM (
            SELECT r, json_extract(t, '\$.content[0].text') AS x FROM m
            WHERE json_extract(t, '\$.role') = 'user'
          ) WHERE x IS NOT NULL AND instr(x, '<user_query>') > 0
        )
        UNION ALL
        SELECT m.r, 'cursor [assistant] ' || x FROM m, (
          SELECT json_extract(v.value, '\$.text') AS x
          FROM json_each(json_extract(m.t, '\$.content')) v
          WHERE json_extract(v.value, '\$.type') = 'text' LIMIT 1
        ) WHERE json_extract(m.t, '\$.role') = 'assistant' AND x IS NOT NULL
      ) ORDER BY r;
    " 2>/dev/null
  done
}

claude_logs
codex_logs
cursor_logs
