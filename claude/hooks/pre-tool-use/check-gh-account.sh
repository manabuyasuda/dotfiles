#!/bin/bash
# =============================================================================
# pre-tool-use/check-gh-account.sh — ghコマンド実行前にGitHubアカウントを確認
# =============================================================================
# フック  : PreToolUse（Bash）
# 役割   : Bashコマンドに gh が含まれる場合、アクティブなGitHubアカウントと
#          EXPECTED_GH_ACCOUNT を比較し、不一致なら警告して切り替えを促す。
#
# 設定方法:
#   プロジェクトの .claude/settings.local.json に期待するアカウントを設定する。
#   EXPECTED_GH_ACCOUNT が未設定のプロジェクトではこのhookはスキップされる。
#
#   例）.claude/settings.local.json:
#   {
#     "env": {
#       "EXPECTED_GH_ACCOUNT": "your-github-username"
#     }
#   }
#
# 複数アカウントの切り替え:
#   gh auth switch --user <username>
#
# 終了コード:
#   0  → 通過（アカウント一致 / EXPECTED_GH_ACCOUNT 未設定 / gh以外のコマンド）
#   2  → 警告（アカウント不一致）処理は続行されるがメッセージを表示
# =============================================================================

if [ -z "$EXPECTED_GH_ACCOUNT" ]; then
  exit 0
fi

# stdinからツール入力を読んでghコマンドかどうか確認
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null)

if ! echo "$COMMAND" | grep -qE '(^|\s|\|)gh(\s|$)'; then
  exit 0
fi

ACTIVE_ACCOUNT=$(gh api user --jq '.login' 2>/dev/null)

if [ -z "$ACTIVE_ACCOUNT" ]; then
  exit 0
fi

if [ "$ACTIVE_ACCOUNT" != "$EXPECTED_GH_ACCOUNT" ]; then
  echo "⚠️  ghアカウントが違います: 現在=$ACTIVE_ACCOUNT, 期待=$EXPECTED_GH_ACCOUNT" >&2
  echo "切り替えるには: gh auth switch --user $EXPECTED_GH_ACCOUNT" >&2
  exit 2
fi

exit 0
