#!/bin/bash
# mermaid-guard/post.sh - Write/Edit PostToolUse hook
# .md ファイル内の Mermaid ブロックを mmdc で構文チェックする

LOG_FILE="$HOME/.claude/mermaid-guard.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

INPUT=$(cat)
FILE_PATH=$(jq -r '.tool_input.file_path // ""' <<< "$INPUT")

[[ "$FILE_PATH" != *.md ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0

ERRORS=""
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

block_num=0
in_block=false
block_lines=()

while IFS= read -r line; do
  if [[ "$line" =~ ^\`\`\`mermaid ]]; then
    in_block=true
    block_lines=()
    continue
  fi

  if [[ "$line" == '```' ]] && [[ "$in_block" == true ]]; then
    in_block=false
    block_num=$((block_num + 1))
    tmp_file="$TMP_DIR/block_${block_num}.mmd"
    printf '%s\n' "${block_lines[@]}" > "$tmp_file"

    mmdc_out=$(mmdc -i "$tmp_file" -o "$TMP_DIR/out_${block_num}.svg" 2>&1)
    err_msg=$(grep -A 3 "^Error" <<< "$mmdc_out" | head -4)
    if [[ -n "$err_msg" ]]; then
      log "[${FILE_PATH##*/}] block${block_num} mmdc ERROR: $err_msg"
      ERRORS="${ERRORS}[ブロック${block_num}] 構文エラー（mmdc）:
${err_msg}

"
    fi

    continue
  fi

  [[ "$in_block" == true ]] && block_lines+=("$line")
done < "$FILE_PATH"

if [[ -n "$ERRORS" ]]; then
  jq -n --arg reason "Mermaid 検証エラーが見つかりました。修正してください:

${ERRORS}" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 2
fi
