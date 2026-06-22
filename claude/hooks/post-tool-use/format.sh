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
#   *.md                        → textlint + 校正指示で文章品質改善
#                                  1. textlint --fix で自動修正
#                                  2. 校正をfeedbackで指示（実施手段はAIエージェントに委ねる）
#                                     （textlint 残存エラーも合わせて渡す）
#                                  3. スキルが変更なしと判断したら自然終了
#   それ以外                    → 何もしない（exit 0 で通過）
#
# フォーマッター解決の優先順位:
#   1. $FORMATTER（session-start.sh が $CLAUDE_ENV_FILE に保存した値）
#   2. node_modules/.bin/biome（ローカルインストールを確認）
#   3. node_modules/.bin/oxfmt / oxfmt（ローカル → グローバル）
#   4. prettier（グローバルフォールバック）
#
# 出力（PostToolUse の hookSpecificOutput.additionalContext 経由）:
#   成功: {"suppressOutput": true} を stdout、exit 0
#   失敗: {"hookSpecificOutput": {"hookEventName": "PostToolUse",
#         "additionalContext": "ERROR: ..."}} を stdout、exit 0
#         additionalContext が次回モデル呼び出し時の context に注入される
#
# 入力 : stdin の JSON（tool_input.file_path）— 編集されたファイルのパス
#        $FORMATTER（session-start.sh が設定した環境変数、未設定時は自動検出）
# =============================================================================
INPUT=$(cat)
file=$(jq -r '.tool_input.file_path // ""' <<<"$INPUT")

# JS/TS でも .md でもないファイルは対象外
[[ "$file" =~ \.(js|jsx|ts|tsx|md)$ ]] || exit 0

# --- フォーマッター解決（$FORMATTER 優先 → ローカル → グローバルの順）---
# oxfmt はローカル・グローバルどちらも同じ "oxfmt" を返し、実行時に判断する
_resolve_fmt() {
  if [ -n "${FORMATTER:-}" ]; then echo "$FORMATTER"; return; fi
  if [ -x "node_modules/.bin/biome" ]; then echo "biome"; return; fi
  if [ -x "node_modules/.bin/oxfmt" ] || command -v oxfmt &>/dev/null; then echo "oxfmt"; return; fi
  echo "prettier"
}

# --- JS/TS: フォーマッターを実行 ---
if [[ "$file" =~ \.(js|jsx|ts|tsx)$ ]]; then
  case "$(_resolve_fmt)" in
    biome)
      node_modules/.bin/biome check --write "$file" 2>&1 ;;
    oxfmt)
      # ローカルインストールを優先し、なければグローバルの oxfmt を使う
      if [ -x "node_modules/.bin/oxfmt" ]; then
        node_modules/.bin/oxfmt --write "$file" 2>&1
      else
        oxfmt --write "$file" 2>&1
      fi ;;
    *)
      npx prettier --write "$file" 2>&1 ;;
  esac
  exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo '{"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "ERROR: フォーマットに失敗しました。WHY: ファイルに構文エラーが含まれている可能性があります。FIX: 構文エラーを修正してください。"}}'
    exit 0
  fi
  echo '{"suppressOutput": true}'
  exit 0
fi

# --- .md: textlint + 校正指示で文章品質を確認 ---

# ファイルのディレクトリから上に向かって node_modules/.bin/textlint を探す
textlint_cmd=""
textlint_cwd=""
search_dir="$(dirname "$file")"
while [ "$search_dir" != "/" ]; do
  if [ -x "$search_dir/node_modules/.bin/textlint" ]; then
    textlint_cmd="$search_dir/node_modules/.bin/textlint"
    textlint_cwd="$search_dir"
    break
  fi
  search_dir="$(dirname "$search_dir")"
done

# textlint --fix を適用後、残存エラーを収集
textlint_remaining=""
if [ -n "$textlint_cmd" ]; then
  cd "$textlint_cwd" && $textlint_cmd --fix "$file" > /dev/null 2>&1
  remaining_output=$(cd "$textlint_cwd" && $textlint_cmd "$file" 2>&1)
  [ $? -ne 0 ] && textlint_remaining="$remaining_output"
fi

# git diff で変更箇所を取得（レビュー範囲を変更行に絞るため）
git_diff_section=""
if git -C "$(dirname "$file")" rev-parse --git-dir &>/dev/null 2>&1; then
  diff_output=$(git diff "$file" 2>/dev/null)
  if [ -n "$diff_output" ]; then
    git_diff_section="

     変更差分:
${diff_output}"
  fi
fi

# 校正を指示（実施手段はAIエージェントに委ねる）
# textlint 残存エラーがある場合はそれも添付してエージェントに渡す
if [ -n "$textlint_remaining" ]; then
  msg="ERROR: textlint エラーが残っています。\nWHY: textlint --fix で自動修正できない違反が残っています。\nFIX: このファイルの日本語文章を校正してください。\nファイル: ${file}\n\ntextlint 残存エラー:\n${textlint_remaining}${git_diff_section}"
else
  msg="ERROR: 文章の校正が必要です。\nWHY: textlint を通過しても文章ルールへの違反が残っている可能性があります。\nFIX: このファイルの日本語文章を校正してください。\nファイル: ${file}${git_diff_section}"
fi
feedback=$(printf '%s' "$msg" | python3 -c "import json,sys; print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': sys.stdin.read()}}))")
echo "$feedback"
exit 0
