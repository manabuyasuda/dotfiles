#!/bin/bash
# bash-guard.sh - Bash tool PreToolUse hook
#
# 以下を機械的に強制する:
# 1. descriptionパラメータの必須化（コマンドの理由・目的を明示させる）
# 2. 破壊的コマンド実行時のユーザー承認（rm, find -delete, unlink等）
# 3. git commit/push実行時のユーザー承認

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // ""')

# --- 1. descriptionが空ならブロック ---
if [ -z "$DESCRIPTION" ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Bashコマンドにはdescriptionパラメータが必須です。コマンドの理由と目的を日本語で記述してください。"
    }
  }'
  exit 0
fi

# --- 2. 破壊的なファイル操作 → ユーザー承認を要求 ---
# rm, unlink, shred: ファイル・ディレクトリの削除
# find -delete: findの結果を直接削除
# find -exec rm: findの結果をrmで削除
if echo "$COMMAND" | grep -qwE 'rm|unlink|shred|truncate' || \
   echo "$COMMAND" | grep -qE 'find[[:space:]].*-delete' || \
   echo "$COMMAND" | grep -qE 'find[[:space:]].*-exec[[:space:]]+rm'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: "データ削除を伴うコマンドです。実行してよいか確認してください。"
    }
  }'
  exit 0
fi

# --- 3. git commit/push → ユーザー承認を要求 ---
if echo "$COMMAND" | grep -qE 'git[[:space:]]+(commit|push)'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: "gitのcommit/pushはユーザーの承認が必要です。"
    }
  }'
  exit 0
fi

# --- その他のコマンドは許可 ---
exit 0
