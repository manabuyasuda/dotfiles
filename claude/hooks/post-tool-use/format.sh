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
# 出力:
#   成功（JS/TS フォーマット成功 など）:
#     {"suppressOutput": true} を stdout、exit 0
#   JS/TS フォーマット失敗:
#     {"hookSpecificOutput": {"hookEventName": "PostToolUse",
#      "additionalContext": "ERROR: ..."}} を stdout、exit 0
#     additionalContext は次回モデル呼び出し時の context に注入される（弱い通知）。
#   .md で校正が必要なとき:
#     {"decision": "block", "reason": "..."} を stdout、exit 0
#     decision: block は親エージェントを強くブロックし、reason を必ず見せる
#     （additionalContext は親が拾い漏らす実例があったため、校正経路は block に統一）。
#
# サブエージェント識別:
#   stdin の JSON に agent_id が含まれる場合（サブエージェント内の Edit）はスキップする。
#   japanese-writing-review サブエージェントが校正のために Edit するたびに block すると
#   無限ネストを起こすため、サブエージェント内の Edit には本フックを発火させない。
#
# 入力 : stdin の JSON（tool_input.file_path, agent_id）
#        $FORMATTER（session-start.sh が設定した環境変数、未設定時は自動検出）
# =============================================================================
INPUT=$(cat)
file=$(jq -r '.tool_input.file_path // ""' <<<"$INPUT")
agent_id=$(jq -r '.agent_id // ""' <<<"$INPUT")

# サブエージェント内の Edit ではスキップする（無限ネスト防止）
[[ -n "$agent_id" ]] && exit 0

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

# 校正を強制する（decision: block で親エージェントに必ず読ませる）。
# 親は reason を読んで Task tool で japanese-writing-review サブエージェントを起動する。
# サブエージェント内の Edit はスクリプト冒頭の agent_id 判定でスキップされるため、再帰しない。
if [ -n "$textlint_remaining" ]; then
  msg="ERROR: 日本語の.md編集後に校正が未実施です。次の作業に進む前に Task tool で japanese-writing-review サブエージェントを起動し、このファイルの校正を完了してください。\n\nWHY: textlint --fix で自動修正できない違反が残っています。サブエージェントが3周ループで評価→編集を繰り返し、親コンテキストを汚さずに校正します。\n\nFIX: Task tool で japanese-writing-review を呼び、対象ファイルを引数として渡してください。校正の対象は下記の変更差分スニペットだけです。サブエージェントは対象ファイルをReadせず、スニペット内の文章だけを判定材料にします。\n\nファイル: ${file}\n\ntextlint 残存エラー:\n${textlint_remaining}${git_diff_section}"
else
  msg="ERROR: 日本語の.md編集後に校正が未実施です。次の作業に進む前に Task tool で japanese-writing-review サブエージェントを起動し、このファイルの校正を完了してください。\n\nWHY: textlint を通過しても文章ルールへの違反が残っている可能性があります。サブエージェントが3周ループで評価→編集を繰り返し、親コンテキストを汚さずに校正します。\n\nFIX: Task tool で japanese-writing-review を呼び、対象ファイルを引数として渡してください。校正の対象は下記の変更差分スニペットだけです。サブエージェントは対象ファイルをReadせず、スニペット内の文章だけを判定材料にします。\n\nファイル: ${file}${git_diff_section}"
fi
printf '%s' "$msg" | python3 -c "import json,sys; print(json.dumps({'decision': 'block', 'reason': sys.stdin.read()}))"
exit 0
