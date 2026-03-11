#!/bin/bash
# mermaid-guard/pre.sh - Write/Edit PreToolUse hook
# .md ファイルへの書き込み前に \n リテラルを検出してブロックする

INPUT=$(cat)
TOOL_NAME=$(jq -r '.tool_name // ""' <<< "$INPUT")
FILE_PATH=$(jq -r '.tool_input.file_path // ""' <<< "$INPUT")

[[ "$FILE_PATH" != *.md ]] && exit 0

if [[ "$TOOL_NAME" == "Edit" ]]; then
  CONTENT=$(jq -r '.tool_input.new_string // ""' <<< "$INPUT")
elif [[ "$TOOL_NAME" == "Write" ]]; then
  CONTENT=$(jq -r '.tool_input.content // ""' <<< "$INPUT")
else
  exit 0
fi

if echo "$CONTENT" | grep -qF '\n'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Mermaid ラベル内に \\n が含まれています。\\n は使用禁止です。ラベルを短くするか、ノードを分割してください。"
    }
  }'
  exit 2
fi
