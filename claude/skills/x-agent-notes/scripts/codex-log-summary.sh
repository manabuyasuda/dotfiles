#!/usr/bin/env bash
# Codex rollout JSONL summarizer.
# Emits a small agent-readable summary of a session's activity.
#
# Usage:
#   codex-log-summary.sh --cwd <path> [--since <unix_ts>] [--section <name>]
#   codex-log-summary.sh --file <rollout.jsonl> [--section <name>]
#
# Sections (comma-separated to --section, default = all):
#   files       target rollout files matched by --cwd (+ --since)
#   utterances  human/assistant speech, first ~100 chars
#   tools       tool call counts per name
#   failures    exec calls whose output[0].text starts with "Script failed"
#   tokens      last cumulative token_count for the session

set -euo pipefail

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
SESSIONS_DIR="$CODEX_HOME/sessions"
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
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

has_section() { [[ ",$SECTIONS," == *",$1,"* ]]; }

find_files() {
  # Print rollout JSONL files whose session_meta.payload.cwd matches $CWD
  # and (if --since given) mtime >= SINCE (unix seconds).
  local find_args=("$SESSIONS_DIR" -type f -name "rollout-*.jsonl")
  if [[ -n "$SINCE" ]]; then
    # BSD find cannot parse "@<unix>"; convert epoch to ISO via BSD date -r.
    find_args+=(-newermt "$(date -r "$SINCE" '+%Y-%m-%dT%H:%M:%S')")
  fi
  find "${find_args[@]}" 2>/dev/null | while read -r f; do
    if jq -e --arg cwd "$CWD" '
      select(.type=="session_meta") | .payload.cwd == $cwd
    ' "$f" >/dev/null 2>&1; then
      echo "$f"
    fi
  done
}

section_files() {
  echo "## files"
  if [[ -n "$FILE" ]]; then
    echo "$FILE"
  else
    find_files
  fi
}

# Utterance filter: keep human-like user messages plus assistant replies.
utterances_jq='
  def preview: (. // "") | gsub("\\s+"; " ") | .[0:100];
  def is_injected(t):
      (t | startswith("#"))
    or (t | startswith("<"))
    or (t | startswith("Use the subagent definition at"))
    or (t | startswith("コミット計画を作成してください"))
    or (t | startswith("コミット計画を修正してください"))
    or (t | startswith("作業範囲が変更されたため"));
  select(.type=="response_item" and .payload.type=="message")
  | . as $r
  | ($r.payload.content // [] | map(.text // "") | join("\n")) as $t
  | select($t | length > 0)
  | select(
      ($r.payload.role == "assistant")
      or ($r.payload.role == "user" and (is_injected($t) | not))
    )
  | "\($r.timestamp) [\($r.payload.role)] \($t | preview)"
'

section_utterances() {
  echo "## utterances"
  local files
  if [[ -n "$FILE" ]]; then files="$FILE"; else files="$(find_files)"; fi
  [[ -z "$files" ]] && return
  # shellcheck disable=SC2086
  jq -r "$utterances_jq" $files
}

section_tools() {
  echo "## tools"
  local files
  if [[ -n "$FILE" ]]; then files="$FILE"; else files="$(find_files)"; fi
  [[ -z "$files" ]] && return
  # shellcheck disable=SC2086
  jq -r '
    select(.type=="response_item"
      and (.payload.type=="custom_tool_call" or .payload.type=="function_call"))
    | .payload.name
  ' $files | sort | uniq -c | sort -rn
}

section_failures() {
  echo "## failures"
  local files
  if [[ -n "$FILE" ]]; then files="$FILE"; else files="$(find_files)"; fi
  [[ -z "$files" ]] && return
  # shellcheck disable=SC2086
  # Emit call_id + timestamp for each failed exec. Command text is in the
  # matching custom_tool_call (join by call_id when details are needed).
  jq -r '
    select(.type=="response_item" and .payload.type=="custom_tool_call_output")
    | select((.payload.output | type) == "array")
    | select(((.payload.output[0].text // "")) | startswith("Script failed"))
    | "\(.timestamp) call_id=\(.payload.call_id)"
  ' $files
}

section_tokens() {
  echo "## tokens"
  local files
  if [[ -n "$FILE" ]]; then files="$FILE"; else files="$(find_files)"; fi
  [[ -z "$files" ]] && return
  # Last cumulative token_count in each file.
  for f in $files; do
    jq -r --arg f "$f" '
      select(.type=="event_msg" and .payload.type=="token_count")
      | "\($f | split("/") | .[-1])\t\(.payload.info.total_token_usage.total_tokens)\tweekly_used_percent=\(.payload.rate_limits.primary.used_percent)"
    ' "$f" | tail -1
  done
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
