#!/bin/bash
# bash-guard.sh - Bash tool PreToolUse hook
#
# 以下を機械的に強制する:
# 1. descriptionパラメータの必須化（コマンドの理由・目的を明示させる）
# 2. バックスラッシュ改行（継続行）の禁止（glob が改行文字にマッチせず不要な承認が発生するため）
# 3. 破壊的コマンド実行時のユーザー承認（rm, find -delete, unlink等）
# 4. git push実行時のユーザー承認（リモートへの公開のため特に注意）
# 5. git commit実行時のユーザー承認

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // ""')

# --- 1. descriptionが空ならブロック ---
if [ -z "$DESCRIPTION" ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Bashコマンドにはdescriptionパラメータが必須です。以下の3点を【必ず日本語で】記述してください。英語での記述は認められません。\n(1) コマンドの理由と目的\n(2) リスク度合い（大／中／小）\n(3) 起きうる問題（例: ファイルが削除される、リモートに公開される、設定が上書きされる など）"
    }
  }'
  exit 0
fi

# --- 2. バックスラッシュ改行（継続行）→ ブロック ---
# glob の * は改行文字にマッチしないため、複数行コマンドは許可済みパターンでも
# 承認プロンプトが発生する。コマンドを1行で書き直させることで回避する。
if printf '%s' "$COMMAND" | grep -qP '\\\n'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "⛔ バックスラッシュ改行（継続行）が含まれています。\nallow パターンの glob は改行文字にマッチしないため、承認プロンプトが発生します。\nコマンドをバックスラッシュなしの1行に書き直してください。"
    }
  }'
  exit 0
fi

# --- 3. 破壊的なファイル操作 → ユーザー承認を要求 ---
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
      permissionDecisionReason: "⚠️ データ削除を伴うコマンドです。実行してよいか確認してください。"
    }
  }'
  exit 0
fi

# --- 4. git push → ユーザー承認を要求（リモートへの公開。特に慎重に）---
if echo "$COMMAND" | grep -qE 'git[[:space:]]+push'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: "⚠️ git push を実行しようとしています。実行してよいか確認してください。"
    }
  }'
  exit 0
fi

# --- 5. git commit → Explore.md/Plan.md チェック + ユーザー承認 ---
if echo "$COMMAND" | grep -qE 'git[[:space:]]+commit'; then
  STAGED=$(git -C "${CLAUDE_PROJECT_DIR:-$(pwd)}" diff --cached --name-only 2>/dev/null || echo "")
  if echo "$STAGED" | grep -qE '(^|/)(Explore|Plan|Retrospective)\.md$'; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: "⛔ Explore.md、Plan.md、または Retrospective.md がステージされています。これらはコミットできません。\n以下を実行してから再度コミットしてください:\n  git restore --staged Explore.md Plan.md Retrospective.md"
      }
    }'
    exit 0
  fi
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: "git commit を実行しようとしています。承認してください。"
    }
  }'
  exit 0
fi

# --- その他のコマンドは許可 ---
exit 0
