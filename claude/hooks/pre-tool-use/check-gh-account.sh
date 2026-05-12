#!/usr/bin/env bash
# =============================================================================
# pre-tool-use/check-gh-account.sh — ghコマンド実行前にGitHubアカウントを確認
# =============================================================================
# フック  : PreToolUse（Bash）
# 役割   : Bashコマンドに gh が含まれる場合、アクティブなGitHubアカウントと
#          EXPECTED_GH_ACCOUNT を比較し、不一致なら警告してブロックする。
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
#   0  → 通過（アカウント一致 / EXPECTED_GH_ACCOUNT 未設定 / gh以外のコマンド / gh auth switch）
#   2  → 警告（アカウント不一致）処理は続行されるがメッセージを表示
# =============================================================================

# stderr に警告を出して exit 2 する（exit 2 はソフトブロック：メッセージを表示して処理を止める）
_warn() {
  echo "$1" >&2
  exit 2
}

# EXPECTED_GH_ACCOUNT が未設定のプロジェクトではチェック不要なのでスキップ
if [ -z "$EXPECTED_GH_ACCOUNT" ]; then
  exit 0
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# 引用符内の文字列を除去してパターンマッチングの誤検知を防ぐ
# （例: echo "gh pr list" が gh コマンドとして誤検知されることを防ぐ）
COMMAND_UNQUOTED=$(echo "$COMMAND" | sed 's/"[^"]*"//g; s/'"'"'[^'"'"']*'"'"'//g')

# コマンドの区切り文字（行頭 / 空白 / パイプ）の直後に gh が単独で現れる場合だけ対象とする
# （"gh" が変数名や引数の一部として現れるケースを除外するため境界を厳密に判定する）
if ! echo "$COMMAND_UNQUOTED" | grep -qE '(^|\s|\|)gh(\s|$)'; then
  exit 0
fi

# gh auth switch はアカウント切り替えコマンド自体なのでチェックをスキップする
if echo "$COMMAND_UNQUOTED" | grep -qE 'gh\s+auth\s+switch'; then
  exit 0
fi

# gh CLI が未認証の場合は login を取得できないため、アカウント比較をスキップする
ACTIVE_ACCOUNT=$(gh api user --jq '.login' 2>/dev/null)
if [ -z "$ACTIVE_ACCOUNT" ]; then
  exit 0
fi

if [ "$ACTIVE_ACCOUNT" != "$EXPECTED_GH_ACCOUNT" ]; then
  _warn "WARNING: ghアカウントが違います。WHY: 現在のアクティブアカウント($ACTIVE_ACCOUNT)が期待するアカウント($EXPECTED_GH_ACCOUNT)と異なります。FIX: gh auth switch --user $EXPECTED_GH_ACCOUNT を実行してアカウントを切り替えてから、元のコマンドを再実行してください。"
fi

exit 0
