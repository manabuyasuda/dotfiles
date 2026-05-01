#!/bin/bash
# mermaid-guard/pre.sh - Write/Edit PreToolUse hook
# .md ファイルへの書き込み前に Mermaid ブロック内の \n リテラルを検出してブロックする
# ```mermaid ... ``` の範囲のみを検査し、bash 等の他コードブロックは対象外とする

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

# ```mermaid ... ``` ブロック内の行のみを抽出して検査する
MERMAID_CONTENT=$(echo "$CONTENT" | awk '/^```mermaid/{found=1; next} /^```/{found=0} found{print}')

if echo "$MERMAID_CONTENT" | grep -qF '\n'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "ERROR: Mermaid ラベル内に \\n が含まれています。WHY: \\n はレンダリングエラーの原因になります。FIX: ラベルを短くするか、ノードを分割してください。"
    }
  }'
  exit 2
fi
