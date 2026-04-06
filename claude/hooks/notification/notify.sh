#!/usr/bin/env bash
# =============================================================================
# notification/notify.sh — デスクトップ通知の一元処理
# =============================================================================
# フック  : Notification / Stop
# マッチャー: permission_prompt | idle_prompt | elicitation_dialog（settings.json 側で指定）
#             Stop フックでも同スクリプトを使用する
# 役割   : Claude Code の通知イベントを terminal-notifier でデスクトップ通知として表示する。
#          stdin の JSON から hook_event_name / notification_type / message を読み取り、
#          1ファイルで全通知種別を処理する。
#
# stdin JSON フィールド（Claude Code が渡す）:
#   hook_event_name   : フックイベント種別（"Notification" / "Stop"）
#   notification_type : 通知種別（Notification フック時のみ）
#     permission_prompt   … Claude がツール実行の許可を求めるとき
#     idle_prompt         … Claude が入力待ち状態になったとき
#     elicitation_dialog  … MCP サーバーがユーザー入力をリクエストするとき
#     auth_success        … 認証が成功したとき（このスクリプトでは通知しない）
#   title             : Claude Code が生成したタイトル（英語、省略される場合あり）
#   message           : Claude Code が生成した本文（英語）
#
# 環境変数:
#   CLAUDE_PROJECT_DIR : プロジェクトパス（Claude Code が自動設定）
#
# 依存ツール: terminal-notifier（brew install terminal-notifier）
#
# 出典: https://code.claude.com/docs/en/hooks.md#notification
# =============================================================================

INPUT=$(cat)
event=$(echo "$INPUT"      | jq -r '.hook_event_name // ""')
type=$(echo "$INPUT"       | jq -r '.notification_type // ""')
claude_msg=$(echo "$INPUT" | jq -r '.message // ""')

# Stop フック（Claude の応答完了）は応答テキストをそのまま通知本文にする。
if [ "$event" = "Stop" ]; then
  project=$(basename "${CLAUDE_PROJECT_DIR:-$(pwd)}")
  terminal-notifier \
    -sender com.apple.Terminal \
    -title "Claude Code: $project" \
    -message "$claude_msg" \
    -sound Glass
  exit 0
fi

# Notification フック: notification_type ごとに通知するか判断する。
# auth_success は情報通知のため通知しない。
case "$type" in
  permission_prompt|idle_prompt|elicitation_dialog)
    : # 通知する
    ;;
  *)
    exit 0
    ;;
esac

project=$(basename "${CLAUDE_PROJECT_DIR:-$(pwd)}")

# Claude Code の message をそのまま通知本文にする。
msg="$claude_msg"

terminal-notifier \
  -sender com.apple.Terminal \
  -title "Claude Code: $project" \
  -message "$msg" \
  -sound Glass

exit 0
