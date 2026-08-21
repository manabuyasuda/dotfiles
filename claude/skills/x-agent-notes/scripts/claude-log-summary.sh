#!/usr/bin/env bash
# Claude Code transcript JSONL summarizer.
# Same interface and sections as codex-log-summary.sh; only the log location
# and the extraction queries differ.
#
# Usage:
#   claude-log-summary.sh --cwd <path> [--since <unix_ts>] [--section <name>]
#   claude-log-summary.sh --file <transcript.jsonl> [--section <name>]
#
# Sections (comma-separated to --section, default = all):
#   files       transcript files under ~/.claude/projects/<cwd-slug>/ (+ --since)
#   utterances  human/assistant speech, first ~100 chars
#   tools       tool call counts per name
#   failures    tool_result records with is_error == true
#   tokens      usage of the last assistant message per file

set -euo pipefail

CLAUDE_PROJECTS="${CLAUDE_PROJECTS:-$HOME/.claude/projects}"
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

# cwd slug: "/" and "." both become "-" (e.g. /Users/a.b/x -> -Users-a-b-x).
slug() { printf '%s' "$1" | tr '/.' '--'; }

find_files() {
  local dir="$CLAUDE_PROJECTS/$(slug "$CWD")"
  [[ -d "$dir" ]] || return 0
  local find_args=("$dir" -type f -name "*.jsonl")
  if [[ -n "$SINCE" ]]; then
    # BSD find cannot parse "@<unix>"; convert epoch to ISO via BSD date -r.
    find_args+=(-newermt "$(date -r "$SINCE" '+%Y-%m-%dT%H:%M:%S')")
  fi
  find "${find_args[@]}" 2>/dev/null
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
# Injected user records (system-reminder / command tags / caveats) start with
# "<" or "Caveat:".
utterances_jq='
  def preview: (. // "") | gsub("\\s+"; " ") | .[0:100];
  def text_of:
    .message.content
    | if type=="string" then .
      else ([.[]? | select(.type=="text") | .text] | join("\n"))
      end;
  select(.type=="user" or .type=="assistant")
  | . as $r
  | (text_of // "") as $t
  | select($t | length > 0)
  | select(
      ($r.type == "assistant")
      or ($r.type == "user"
          and (($t | startswith("<")) or ($t | startswith("Caveat:")) | not))
    )
  | "\($r.timestamp) [\($r.type)] \($t | preview)"
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
    select(.type=="assistant")
    | .message.content
    | select(type=="array")
    | .[]
    | select(.type=="tool_use")
    | .name
  ' $files | sort | uniq -c | sort -rn
}

section_failures() {
  echo "## failures"
  local files
  if [[ -n "$FILE" ]]; then files="$FILE"; else files="$(find_files)"; fi
  [[ -z "$files" ]] && return
  # shellcheck disable=SC2086
  # Emit tool_use_id + timestamp for each failed tool call. The command text is
  # in the matching assistant tool_use (join by id when details are needed).
  jq -r '
    select(.type=="user")
    | . as $r
    | .message.content
    | select(type=="array")
    | .[]
    | select(.type=="tool_result" and .is_error==true)
    | "\($r.timestamp) tool_use_id=\(.tool_use_id)"
  ' $files
}

section_tokens() {
  echo "## tokens"
  local files
  if [[ -n "$FILE" ]]; then files="$FILE"; else files="$(find_files)"; fi
  [[ -z "$files" ]] && return
  # Usage of the last assistant message per file (input incl. cache + output).
  for f in $files; do
    jq -r --arg f "$f" '
      select(.type=="assistant" and .message.usage != null)
      | .message.usage as $u
      | "\($f | split("/") | .[-1])\tinput=\(($u.input_tokens // 0) + ($u.cache_read_input_tokens // 0) + ($u.cache_creation_input_tokens // 0))\toutput=\($u.output_tokens // 0)"
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
