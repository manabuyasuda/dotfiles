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
# 出力（feedback）:
#   エラーなし: {"feedback": "No TypeScript errors.", "suppressOutput": true}
#   エラーあり: エラー内容（先頭30行）を stderr に出力 + feedback でエージェントに通知
#
# 入力 : $CLAUDE_TOOL_INPUT_FILE_PATH
# =============================================================================
[[ "$CLAUDE_TOOL_INPUT_FILE_PATH" =~ \.(ts|tsx)$ ]] || exit 0

echo '{"feedback": "Checking TypeScript types..."}' >&2
output=$(npx tsc --noEmit 2>&1)
if [ $? -eq 0 ]; then
  echo '{"feedback": "No TypeScript errors.", "suppressOutput": true}'
else
  errors=$(echo "$output" | grep -A 2 "error TS" | head -30)
  [ -n "$errors" ] && echo "$errors" >&2
  echo '{"feedback": "TypeScript found type errors. See output above."}' >&2
fi
exit 0
