#!/usr/bin/env bash
# =============================================================================
# pre-tool-use/push-to-main-guard.sh — 保護ブランチへの git push を deny でブロック
# =============================================================================
# フック  : PreToolUse（Bash）
#
# bash-guard.sh はすべての git push を ask で確認するが、
# 保護ブランチへの push は deny で強制ブロックしたいため、このスクリプトで補完する。
#
# bash-guard.sh との役割分担:
#   - 保護ブランチへの push → このスクリプトが deny（deny が優先）
#   - フィーチャーブランチへの push → bash-guard.sh が ask
# =============================================================================

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../config.sh
source "$HOOKS_DIR/config.sh"

INPUT=$(cat)
cmd=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# git push コマンドでなければスキップ
echo "$cmd" | grep -qE 'git[[:space:]]+push' || exit 0

_deny() {
  jq -n \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"ERROR: 保護ブランチへの直接 push は禁止されています。WHY: レビュープロセスを迂回するためです。FIX: フィーチャーブランチから Pull Request を作成してください。"}}'
  exit 0
}

# 引数に保護ブランチ名が含まれる場合（例: git push origin main）
# glob パターン（"release/*"等）は grep で直接使えないため、ワイルドカードなしのブランチ名のみ対象
for pattern in "${PROTECTED_BRANCHES[@]}"; do
  if [[ "$pattern" != *"*"* ]] && echo "$cmd" | grep -qE "[[:space:]]${pattern}([[:space:]]|$)"; then
    _deny
  fi
done

# 引数なし、またはリモート名のみの push → 現在ブランチを確認
if echo "$cmd" | grep -qE '^[[:space:]]*git[[:space:]]+push[[:space:]]*$' || \
   echo "$cmd" | grep -qE '^[[:space:]]*git[[:space:]]+push[[:space:]]+[a-zA-Z0-9_.-]+[[:space:]]*$'; then
  CURRENT=$(git -C "${CLAUDE_PROJECT_DIR:-$(pwd)}" branch --show-current 2>/dev/null)
  for pattern in "${PROTECTED_BRANCHES[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$CURRENT" == $pattern ]]; then
      _deny
    fi
  done
fi

exit 0
