#!/usr/bin/env bash
# Cursor CLI chat store.db summarizer.
# Same interface and sections as claude-log-summary.sh / codex-log-summary.sh;
# only the log location and the extraction queries differ.
#
# Usage:
#   cursor-log-summary.sh --cwd <path> [--since <unix_ts>] [--section <name>]
#   cursor-log-summary.sh --file <store.db> [--section <name>]
#
# Sections (comma-separated to --section, default = all):
#   files       store.db files under ~/.cursor/chats/<md5(cwd)>/ (+ --since)
#   utterances  human/assistant speech, first ~100 chars
#   tools       tool call counts per name
#   failures    tool records containing "isError":true
#   tokens      not recorded in store.db (section prints a note)

set -euo pipefail

CURSOR_CHATS="${CURSOR_CHATS:-$HOME/.cursor/chats}"
CWD=""
SINCE=""
FILE=""
SECTIONS="files,utterances,tools,failures,tokens"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd) CWD="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --file) FILE="$2"; shift 2 ;;
    --section) SECTIONS="$2"; shift 2 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Cursor buckets sessions by the MD5 of the workspace path (BSD md5 -q).
cwd_hash() { printf '%s' "$1" | md5 -q; }

find_files() {
  local dir="$CURSOR_CHATS/$(cwd_hash "$CWD")"
  [[ -d "$dir" ]] || return 0
  local find_args=("$dir" -type f -name "store.db")
  if [[ -n "$SINCE" ]]; then
    # BSD find cannot parse "@<unix>"; convert epoch to ISO via BSD date -r.
    find_args+=(-newermt "$(date -r "$SINCE" '+%Y-%m-%dT%H:%M:%S')")
  fi
  find "${find_args[@]}" 2>/dev/null
}

target_files() {
  if [[ -n "$FILE" ]]; then echo "$FILE"; else find_files; fi
}

section_files() {
  echo "## files"
  target_files
}

# blobs.data mixes JSON messages with binary blobs; json_valid() guards every
# query. blobs has no timestamp column, so rowid order approximates message
# order. Real user messages carry a <user_query> tag; injected records
# (<user_info> etc.) do not.
utterances_sql=$(cat <<'SQL'
WITH m AS (
  SELECT rowid AS r, CAST(data AS TEXT) AS t FROM blobs
  WHERE json_valid(CAST(data AS TEXT))
),
u AS (
  SELECT r, json_extract(t, '$.content[0].text') AS x FROM m
  WHERE json_extract(t, '$.role') = 'user'
),
uq AS (
  SELECT r, substr(x, instr(x, '<user_query>') + 12) AS rest FROM u
  WHERE x IS NOT NULL AND instr(x, '<user_query>') > 0
),
a AS (
  SELECT m.r AS r,
         (SELECT json_extract(v.value, '$.text')
          FROM json_each(json_extract(m.t, '$.content')) v
          WHERE json_extract(v.value, '$.type') = 'text' LIMIT 1) AS x
  FROM m WHERE json_extract(m.t, '$.role') = 'assistant'
)
SELECT msg FROM (
  SELECT r, '[user] ' || substr(replace(replace(
    substr(rest, 1, instr(rest, '</user_query>') - 1),
    char(10), ' '), char(13), ' '), 1, 100) AS msg FROM uq
  UNION ALL
  SELECT r, '[assistant] ' || substr(replace(replace(
    x, char(10), ' '), char(13), ' '), 1, 100) AS msg FROM a
  WHERE x IS NOT NULL
) ORDER BY r;
SQL
)

section_utterances() {
  echo "## utterances"
  local f
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    echo "# file: $f"
    sqlite3 "$f" "$utterances_sql"
  done <<< "$(target_files)"
}

tools_sql=$(cat <<'SQL'
SELECT json_extract(v.value, '$.toolName')
FROM blobs, json_each(json_extract(CAST(data AS TEXT), '$.content')) v
WHERE json_valid(CAST(data AS TEXT))
  AND json_extract(CAST(data AS TEXT), '$.role') = 'assistant'
  AND json_extract(v.value, '$.type') = 'tool-call';
SQL
)

section_tools() {
  echo "## tools"
  local f
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    sqlite3 "$f" "$tools_sql"
  done <<< "$(target_files)" | sort | uniq -c | sort -rn
}

# Emit rowid + tool name + toolCallId for each failed call. The full result
# text stays in the blob (join by toolCallId when details are needed).
# "isError":true sits at varying depths (providerOptions.cursor.
# highLevelToolCallResult etc.), so match it as a substring of the record.
failures_sql=$(cat <<'SQL'
WITH m AS (
  SELECT rowid AS r, CAST(data AS TEXT) AS t FROM blobs
  WHERE json_valid(CAST(data AS TEXT))
)
SELECT 'rowid=' || m.r
  || ' tool=' || COALESCE(json_extract(m.t, '$.content[0].toolName'), '?')
  || ' id=' || COALESCE(json_extract(m.t, '$.content[0].toolCallId'), '?')
FROM m
WHERE json_extract(m.t, '$.role') = 'tool'
  AND instr(m.t, '"isError":true') > 0;
SQL
)

section_failures() {
  echo "## failures"
  local f
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    echo "# file: $f"
    sqlite3 "$f" "$failures_sql"
  done <<< "$(target_files)"
}

section_tokens() {
  echo "## tokens"
  echo "(store.db does not record token usage)"
}

IFS=',' read -ra WANT <<< "$SECTIONS"
for s in "${WANT[@]}"; do
  case "$s" in
    files) section_files ;;
    utterances) section_utterances ;;
    tools) section_tools ;;
    failures) section_failures ;;
    tokens) section_tokens ;;
    *) echo "unknown section: $s" >&2 ;;
  esac
  echo
done
