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
#   0 → テスト成功
#   1 → テスト失敗（エージェントに修正させる）
#
# 出力（feedback）:
#   テスト成功: {"feedback": "Tests passed."}
#   テスト失敗: {"feedback": "ERROR: ..."} → exit 1 でエージェントに修正させる
#
# 入力 : $CLAUDE_TOOL_INPUT_FILE_PATH
#        $TEST_RUNNER（session-start.sh が設定した環境変数、未設定時は自動検出）
# =============================================================================
[[ "$CLAUDE_TOOL_INPUT_FILE_PATH" =~ \.test\.(js|jsx|ts|tsx)$ ]] || exit 0

# $TEST_RUNNER → vitest（ローカル） → jest の順で解決する
_resolve_runner() {
  if [ -n "${TEST_RUNNER:-}" ]; then echo "$TEST_RUNNER"; return; fi
  [ -x "node_modules/.bin/vitest" ] && echo "vitest" || echo "jest"
}

echo '{"feedback": "Running tests..."}' >&2
# case の各ブランチはパイプコマンドのみ。exit_code は case 完了後に PIPESTATUS で一括取得する。
case "$(_resolve_runner)" in
  vitest) npx vitest run --reporter=verbose "$CLAUDE_TOOL_INPUT_FILE_PATH" 2>&1 | tail -30 ;;
  *)      npm test -- --findRelatedTests "$CLAUDE_TOOL_INPUT_FILE_PATH" --passWithNoTests 2>&1 | tail -30 ;;
esac
exit_code=${PIPESTATUS[0]}

if [ $exit_code -eq 0 ]; then
  echo '{"feedback": "Tests passed."}'
else
  echo '{"feedback": "ERROR: テストが失敗しました。WHY: 変更がテストを壊している可能性があります。FIX: 上記のテスト出力を確認してコードを修正してください。"}' >&2
  exit 1
fi
