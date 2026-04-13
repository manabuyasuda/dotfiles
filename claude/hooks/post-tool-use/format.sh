#!/usr/bin/env bash
# =============================================================================
# post-tool-use/format.sh — 編集後の自動フォーマット
# =============================================================================
# フック  : PostToolUse（Edit / MultiEdit / Write）
# 役割   : ファイル編集のたびにフォーマッターを自動実行し、
#          エージェントがフォーマット漏れのまま次の作業へ進むことを防ぐ。
#
# 対象ファイル:
#   *.js / *.jsx / *.ts / *.tsx → biome / oxfmt / prettier でフォーマット
#   *.md                        → textlint で自動修正（textlint がある場合のみ）
#   それ以外                    → 何もしない（exit 0 で通過）
#
# フォーマッター解決の優先順位:
#   1. $FORMATTER（session-start.sh が $CLAUDE_ENV_FILE に保存した値）
#   2. node_modules/.bin/biome（ローカルインストールを確認）
#   3. node_modules/.bin/oxfmt / oxfmt（ローカル → グローバル）
#   4. prettier（グローバルフォールバック）
#
# 出力（Claude Code の feedback 機能）:
#   成功: {"feedback": "Formatting applied.", "suppressOutput": true}
#         suppressOutput: true でエージェントの出力に表示しない
#   失敗: {"feedback": "Formatting failed..."} を stdout に出力
#         exit 1 でエージェントに構文エラーを修正させる
#
# 入力 : $CLAUDE_TOOL_INPUT_FILE_PATH（編集されたファイルのパス）
#        $FORMATTER（session-start.sh が設定した環境変数、未設定時は自動検出）
# =============================================================================
file="$CLAUDE_TOOL_INPUT_FILE_PATH"

if [[ "$file" =~ \.(js|jsx|ts|tsx)$ ]]; then
  fmt="${FORMATTER:-}"
  if [ -z "$fmt" ]; then
    if [ -x "node_modules/.bin/biome" ]; then fmt="biome"
    elif [ -x "node_modules/.bin/oxfmt" ] || command -v oxfmt &>/dev/null; then fmt="oxfmt"
    else fmt="prettier"
    fi
  fi
  if [ "$fmt" = "biome" ]; then
    node_modules/.bin/biome check --write "$file" 2>&1
  elif [ "$fmt" = "oxfmt" ]; then
    if [ -x "node_modules/.bin/oxfmt" ]; then
      node_modules/.bin/oxfmt --write "$file" 2>&1
    else
      oxfmt --write "$file" 2>&1
    fi
  else
    npx prettier --write "$file" 2>&1
  fi
  if [ $? -ne 0 ]; then
    echo '{"feedback": "Formatting failed. Check file for syntax errors."}'
    exit 1
  fi
  echo '{"feedback": "Formatting applied.", "suppressOutput": true}'
elif [[ "$file" =~ \.md$ ]]; then
  # ファイルのディレクトリから上に向かって node_modules/.bin/textlint を探す
  textlint_cmd=""
  search_dir="$(dirname "$file")"
  while [ "$search_dir" != "/" ]; do
    if [ -x "$search_dir/node_modules/.bin/textlint" ]; then
      textlint_cmd="$search_dir/node_modules/.bin/textlint"
      textlint_cwd="$search_dir"
      break
    fi
    search_dir="$(dirname "$search_dir")"
  done
  if [ -n "$textlint_cmd" ]; then
    # --fix を適用後、再チェックで残存エラーを検出（--fix は残存エラーがあっても exit 0 するため）
    cd "$textlint_cwd" && $textlint_cmd --fix "$file" > /dev/null 2>&1
    remaining=$(cd "$textlint_cwd" && $textlint_cmd "$file" 2>&1)
    if [ $? -ne 0 ]; then
      feedback=$(printf '%s' "$remaining" | python3 -c "import json,sys; print(json.dumps({'feedback': 'textlint: 自動修正できないエラーがあります。修正してください。\n' + sys.stdin.read()}))")
      echo "$feedback"
      exit 1
    else
      echo '{"feedback": "textlint: auto-fix applied.", "suppressOutput": true}'
    fi
  fi
fi
