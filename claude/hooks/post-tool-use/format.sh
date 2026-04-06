#!/usr/bin/env bash
# =============================================================================
# post-tool-use/format.sh — 編集後の自動フォーマット
# =============================================================================
# フック  : PostToolUse（Edit / MultiEdit / Write）
# 役割   : ファイル編集のたびにフォーマッターを自動実行し、
#          エージェントがフォーマット漏れのまま次の作業へ進むことを防ぐ。
#
# 対象ファイル:
#   *.js / *.jsx / *.ts / *.tsx → biome または prettier でフォーマット
#   *.md                        → textlint で自動修正（textlint がある場合のみ）
#   それ以外                    → 何もしない（exit 0 で通過）
#
# フォーマッター解決の優先順位:
#   1. $FORMATTER（session-start.sh が $CLAUDE_ENV_FILE に保存した値）
#   2. node_modules/.bin/biome（ローカルインストールを確認）
#   3. prettier（グローバルフォールバック）
#
# 出力（Claude Code の feedback 機能）:
#   成功: {"feedback": "Formatting applied.", "suppressOutput": true}
#         suppressOutput: true でエージェントの出力に表示しない
#   失敗: {"feedback": "Formatting failed..."} を stderr に出力
#         exit 1 でエージェントに構文エラーを修正させる
#
# 入力 : $CLAUDE_TOOL_INPUT_FILE_PATH（編集されたファイルのパス）
#        $FORMATTER（session-start.sh が設定した環境変数、未設定時は自動検出）
# =============================================================================
file="$CLAUDE_TOOL_INPUT_FILE_PATH"

if [[ "$file" =~ \.(js|jsx|ts|tsx)$ ]]; then
  fmt="${FORMATTER:-}"
  if [ -z "$fmt" ]; then
    [ -x "node_modules/.bin/biome" ] && fmt="biome" || fmt="prettier"
  fi
  if [ "$fmt" = "biome" ]; then
    node_modules/.bin/biome check --write "$file" 2>&1
  else
    npx prettier --write "$file" 2>&1
  fi
  if [ $? -ne 0 ]; then
    echo '{"feedback": "Formatting failed. Check file for syntax errors."}' >&2
    exit 1
  fi
  echo '{"feedback": "Formatting applied.", "suppressOutput": true}'
elif [[ "$file" =~ \.md$ ]] && [ -x "node_modules/.bin/textlint" ]; then
  output=$(node_modules/.bin/textlint --fix "$file" 2>&1)
  if [ $? -ne 0 ]; then
    echo '{"feedback": "textlint: some issues could not be auto-fixed."}' >&2
    echo "$output" >&2
  else
    echo '{"feedback": "textlint: auto-fix applied.", "suppressOutput": true}'
  fi
fi
