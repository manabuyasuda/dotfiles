#!/usr/bin/env bash
# =============================================================================
# pre-tool-use/push-to-main-guard.sh — 保護ブランチへの git push を deny でブロック
# =============================================================================
# フック  : PreToolUse（Bash）
# 役割   : bash-guard.sh はすべての git push を ask で確認するが、
#          保護ブランチへの push は deny で強制ブロックしたいため、このスクリプトで補完する。
#
# bash-guard.sh との役割分担:
#   - 保護ブランチへの push → このスクリプトが deny（deny が優先）
#   - フィーチャーブランチへの push → bash-guard.sh が ask
#
# 終了コード:
#   0 → 通過（保護ブランチへの push でない）または deny JSON を出力して終了
#
# 入力 : stdin の JSON（tool_input.command）
# =============================================================================

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../config.sh
source "$HOOKS_DIR/config.sh"

INPUT=$(cat)
cmd=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
# push 元ブランチは「いま作業しているディレクトリ（worktree）」で判定する。
# CLAUDE_PROJECT_DIR は worktree に追従しないため、Claude Code が hook 入力で渡す .cwd を使う。
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# git push コマンドでなければスキップ
echo "$cmd" | grep -qE 'git[[:space:]]+push' || exit 0

# メッセージを関数内に固定することで、2つの呼び出しポイントで同じ文言を保証する
_deny() {
  jq -n \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"ERROR: 保護ブランチへの直接 push は禁止されています。WHY: レビューなしに変更が保護ブランチへ反映されるリスクがあります。FIX: フィーチャーブランチから Pull Request を作成してください。"}}'
  exit 0
}

# 引数に保護ブランチ名が含まれる場合（例: git push origin main）
# glob パターン（"release/*"等）は grep で直接使えないため、ワイルドカードなしのブランチ名のみ対象
for pattern in "${PROTECTED_BRANCHES[@]}"; do
  if [[ "$pattern" != *"*"* ]] && echo "$cmd" | grep -qE "[[:space:]]${pattern}([[:space:]]|$)"; then
    _deny
  fi
done

# 引数なし、またはリモート名のみの push（例: git push / git push origin）→ 現在ブランチを確認
# SC2053: [[ == ]] の右辺をクォートしないことで glob 展開を有効にする（意図的）
if echo "$cmd" | grep -qE '^[[:space:]]*git[[:space:]]+push[[:space:]]*$' || \
   echo "$cmd" | grep -qE '^[[:space:]]*git[[:space:]]+push[[:space:]]+[a-zA-Z0-9_.-]+[[:space:]]*$'; then
  CURRENT=$(git -C "${CWD:-$(pwd)}" branch --show-current 2>/dev/null)
  for pattern in "${PROTECTED_BRANCHES[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$CURRENT" == $pattern ]]; then
      _deny
    fi
  done
fi

exit 0
