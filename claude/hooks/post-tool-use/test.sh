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
# 出力（feedback）:
#   テスト成功: {"feedback": "Tests passed."}
#   テスト失敗: {"feedback": "Tests failed. See output above."} → エージェントに修正させる
#
# 入力 : $CLAUDE_TOOL_INPUT_FILE_PATH
#        $TEST_RUNNER（session-start.sh が設定した環境変数、未設定時は自動検出）
# =============================================================================
[[ "$CLAUDE_TOOL_INPUT_FILE_PATH" =~ \.test\.(js|jsx|ts|tsx)$ ]] || exit 0

runner="${TEST_RUNNER:-}"
if [ -z "$runner" ]; then
  [ -x "node_modules/.bin/vitest" ] && runner="vitest" || runner="jest"
fi

echo '{"feedback": "Running tests..."}' >&2
if [ "$runner" = "vitest" ]; then
  npx vitest run --reporter=verbose "$CLAUDE_TOOL_INPUT_FILE_PATH" 2>&1 | tail -30
  exit_code=${PIPESTATUS[0]}
else
  npm test -- --findRelatedTests "$CLAUDE_TOOL_INPUT_FILE_PATH" --passWithNoTests 2>&1 | tail -30
  exit_code=${PIPESTATUS[0]}
fi

if [ $exit_code -eq 0 ]; then
  echo '{"feedback": "Tests passed."}'
else
  echo '{"feedback": "Tests failed. See output above."}' >&2
fi
