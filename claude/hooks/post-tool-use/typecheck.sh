#!/usr/bin/env bash
# =============================================================================
# post-tool-use/typecheck.sh — TypeScript 型チェック（非ブロッキング）
# =============================================================================
# フック  : PostToolUse（Edit / MultiEdit / Write）
# 役割   : TS/TSX ファイルを編集するたびに型チェックを実行し、
#          エージェントが型エラーを蓄積したまま作業を続けることを防ぐ。
#
# 対象ファイル: *.ts / *.tsx のみ（それ以外は即 exit 0）
#
# 非ブロッキング設計:
#   型エラーがあっても exit 0 で終了する。エラーは feedback として渡すのみ。
#   ブロックしない理由: 型エラーがあっても他のファイルの作業は続けられるため。
#   エージェントは feedback を受け取り、適切なタイミングで型エラーを修正する。
#
# 実行コマンド: npx tsc --noEmit（コンパイルせず型チェックのみ）
#
# 終了コード:
#   0 → 常に 0（型エラーがあってもブロックしない設計）
#
# 出力（PostToolUse の hookSpecificOutput.additionalContext 経由）:
#   エラーなし: {"suppressOutput": true} を stdout、exit 0
#   エラーあり: {"hookSpecificOutput": {"hookEventName": "PostToolUse",
#               "additionalContext": "ERROR: ..."}} を stdout、exit 0
#
# 入力 : stdin の JSON（tool_input.file_path）
# =============================================================================
INPUT=$(cat)
file=$(jq -r '.tool_input.file_path // ""' <<<"$INPUT")

[[ "$file" =~ \.(ts|tsx)$ ]] || exit 0

output=$(npx tsc --noEmit 2>&1)
exit_code=$?
if [ $exit_code -eq 0 ]; then
  echo '{"suppressOutput": true}'
  exit 0
fi
errors=$(echo "$output" | grep -A 2 "error TS" | head -30)
msg="ERROR: TypeScript の型エラーが見つかりました。\nWHY: 型エラーはビルドが失敗する原因になります。\nFIX: 下記エラーを確認して型を修正してください。\n\n${errors}"
printf '%s' "$msg" | python3 -c "import json,sys; print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': sys.stdin.read()}}))"
exit 0
