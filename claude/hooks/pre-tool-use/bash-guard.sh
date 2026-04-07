#!/usr/bin/env bash
# =============================================================================
# pre-tool-use/bash-guard.sh — Bash ツール実行前の安全確認
# =============================================================================
# フック  : PreToolUse（Bash）
#
# 強制ルール:
# 1. description が空のコマンドは実行を拒否する
# 2. バックスラッシュ改行（継続行）を含むコマンドは実行を拒否する
# 3. rm（単体）/ unlink / truncate はユーザー確認を取る
# 4. git push は種類に応じてユーザー確認を取る
#      --force-with-lease: リベース後の push として確認
#      --force / -f:       リモート履歴の上書きとして確認
#      通常:               リモート公開として確認
# 5. git commit はパターンに応じて動作が変わる
#      --amend フラグあり:                  公開済みコミット書き換えリスクを伝えてユーザー確認
#      WORK_RECORD_FILES がステージ済み:     作業記録ファイルはコミット禁止のため実行を拒否（config.sh で定義）
#      ステージ済み:
#      通常:                                ユーザー確認を取る
# 6. 保護ブランチ上での git merge は実行を拒否する（PR 経由を強制）
# 7. git reset --hard はユーザー確認を取る
#
# 注: rm -rf / shred / xargs rm / find -delete 等は pre-tool-use/dangerous-guard.sh で拒否済み。
#     並列実行のため、dangerous-guard.sh の拒否がこちらの確認より優先される。
# =============================================================================

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../config.sh
source "$HOOKS_DIR/config.sh"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // ""')

# --- 1. description が空ならブロック ---
if [ -z "$DESCRIPTION" ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "ERROR: description パラメータが未入力です。WHY: 意図不明なコマンドはリスク判断ができません。FIX: description に (1)コマンドの理由と目的 (2)リスク度合い（大/中/小） (3)起きうる問題 を日本語で記述してください。"
    }
  }'
  exit 0
fi

# --- 2. バックスラッシュ改行（継続行）→ ブロック ---
if printf '%s' "$COMMAND" | grep -qP '\\\n'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "ERROR: バックスラッシュ改行（継続行）が含まれています。WHY: allow パターンの glob は改行文字にマッチしないため承認プロンプトが発生します。FIX: コマンドをバックスラッシュなしの1行に書き直してください。"
    }
  }'
  exit 0
fi

# --- 3. 単体ファイル削除 → ユーザー承認（rm -r/-rf / shred / xargs / find 系は dangerous-guard.sh で deny）---
if echo "$COMMAND" | grep -qE '(^|[|;&])[[:space:]]*(sudo[[:space:]]+)?(rm|unlink|truncate)([[:space:]]|$)'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: "ファイル削除・変更を伴うコマンドです。実行してよいか確認してください。"
    }
  }'
  exit 0
fi

# --- 4. git push: --force-with-lease を先に検出（--force への誤マッチを防ぐ）---
if echo "$COMMAND" | grep -qE 'git[[:space:]]+push'; then
  if echo "$COMMAND" | grep -qE -- '--force-with-lease'; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason: "git push --force-with-lease を実行しようとしています。リベース後のフィーチャーブランチへの push ですか？実行してよいか確認してください。"
      }
    }'
    exit 0
  fi
  if echo "$COMMAND" | grep -qE -- '--force|-f[[:space:]]|[[:space:]]-f$'; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason: "git push --force を実行しようとしています。リモートの履歴を上書きします。意図した操作か確認してください。"
      }
    }'
    exit 0
  fi
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: "git push を実行しようとしています。リモートへ公開されます。実行してよいか確認してください。"
    }
  }'
  exit 0
fi

# --- 5. git commit: --amend → ask / 禁止ファイル → deny / 通常 → ask ---
if echo "$COMMAND" | grep -qE 'git[[:space:]]+commit'; then
  if echo "$COMMAND" | grep -qE -- '--amend'; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason: "git commit --amend を実行しようとしています。公開済みコミットの書き換えになる場合は注意してください。実行してよいか確認してください。"
      }
    }'
    exit 0
  fi
  STAGED=$(git -C "${CLAUDE_PROJECT_DIR:-$(pwd)}" diff --cached --name-only 2>/dev/null || echo "")
  # WORK_RECORD_FILES（特定ファイル）と WORK_RECORD_DIRS（ディレクトリ配下全て）を検出
  file_pattern=$(IFS='|'; echo "${WORK_RECORD_FILES[*]}" | sed 's/\./\\./g')
  dir_pattern=$(IFS='|'; echo "${WORK_RECORD_DIRS[*]}")
  matched=$(echo "$STAGED" | grep -E "(^|/)($file_pattern)$|(^|/)($dir_pattern)/")
  if [ -n "$matched" ]; then
    restore_args=$(echo "$matched" | tr '\n' ' ')
    jq -n --arg msg "ERROR: 作業記録ファイルがステージされています。WHY: これらはセッション中の作業記録であり、コミット履歴に含めてはいけません。FIX: git restore --staged ${restore_args}を実行してから再度コミットしてください。" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $msg
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

# --- 6. git merge on 保護ブランチ → deny ---
if echo "$COMMAND" | grep -qE 'git[[:space:]]+merge'; then
  CURRENT_BRANCH=$(git -C "${CLAUDE_PROJECT_DIR:-$(pwd)}" branch --show-current 2>/dev/null || echo "")
  for pattern in "${PROTECTED_BRANCHES[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$CURRENT_BRANCH" == $pattern ]]; then
      jq -n "{
        hookSpecificOutput: {
          hookEventName: \"PreToolUse\",
          permissionDecision: \"deny\",
          permissionDecisionReason: \"ERROR: 保護ブランチ '$CURRENT_BRANCH' へのローカルマージは禁止されています。WHY: 直接マージによる意図しない変更混入を防ぎ、レビューを必須化するためです。FIX: GitHub で Pull Request を作成してください。\"
        }
      }"
      exit 0
    fi
  done
fi

# --- 7. git reset --hard → ask ---
if echo "$COMMAND" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: "git reset --hard を実行しようとしています。未コミットの変更は失われます（コミット済みは reflog で復元可能）。実行してよいか確認してください。"
    }
  }'
  exit 0
fi

# --- その他のコマンドは許可 ---
exit 0
