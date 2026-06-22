#!/usr/bin/env bash
# =============================================================================
# post-tool-use/test.sh — テストファイル変更後の関連テスト自動実行
# =============================================================================
# フック  : PostToolUse（Edit / MultiEdit / Write）
# 役割   : テストファイルを編集するたびに関連テストのみ実行する。
#          エージェントがテストを書いたまま実行せず先に進むことを防ぐ。
#          全テストではなく関連テストのみを実行することで高速なフィードバックを得る。
#
# 対象ファイル: *.test.js / *.test.ts / *.test.tsx 等（それ以外は即 exit 0）
#
# テストランナーの解決順:
#   1. $TEST_RUNNER（session-start.sh が $CLAUDE_ENV_FILE に保存した値）
#   2. node_modules/.bin/vitest（ローカルインストールを確認）
#   3. jest（フォールバック）
#
# 実行コマンド:
#   vitest: npx vitest run --reporter=verbose <file>
#   jest:   npm test -- --findRelatedTests <file> --passWithNoTests
#
# 終了コード:
#   0 → 常に 0（PostToolUse はツール実行後のためブロック不可。
#        テスト失敗は additionalContext で次ターンに通知する）
#
# 出力（PostToolUse の hookSpecificOutput.additionalContext 経由）:
#   テスト成功: {"suppressOutput": true} を stdout、exit 0
#   テスト失敗: {"hookSpecificOutput": {"hookEventName": "PostToolUse",
#               "additionalContext": "ERROR: ..."}} を stdout、exit 0
#
# 入力 : stdin の JSON（tool_input.file_path）
#        $TEST_RUNNER（session-start.sh が設定した環境変数、未設定時は自動検出）
# =============================================================================
INPUT=$(cat)
file=$(jq -r '.tool_input.file_path // ""' <<<"$INPUT")

[[ "$file" =~ \.test\.(js|jsx|ts|tsx)$ ]] || exit 0

# $TEST_RUNNER → vitest（ローカル） → jest の順で解決する
_resolve_runner() {
  if [ -n "${TEST_RUNNER:-}" ]; then echo "$TEST_RUNNER"; return; fi
  [ -x "node_modules/.bin/vitest" ] && echo "vitest" || echo "jest"
}

# case の各ブランチはパイプコマンドのみ。exit_code は case 完了後に PIPESTATUS で一括取得する。
case "$(_resolve_runner)" in
  vitest) output=$(npx vitest run --reporter=verbose "$file" 2>&1 | tail -30) ;;
  *)      output=$(npm test -- --findRelatedTests "$file" --passWithNoTests 2>&1 | tail -30) ;;
esac
exit_code=${PIPESTATUS[0]}

if [ $exit_code -eq 0 ]; then
  echo '{"suppressOutput": true}'
  exit 0
fi
msg="ERROR: テストが失敗しました。\nWHY: 変更がテストを壊している可能性があります。\nFIX: 下記の出力を確認してコードを修正してください。\n\n${output}"
printf '%s' "$msg" | python3 -c "import json,sys; print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': sys.stdin.read()}}))"
exit 0
