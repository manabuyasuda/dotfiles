#!/usr/bin/env bash
# =============================================================================
# stop/textlint-edited-files.sh — このターンで編集した .md を 1 回まとめて textlint する
# =============================================================================
# フック  : Stop
# 役割   : track-edited-files.sh が記録した *.md のうち未処理のものを対象に、
#          textlint がローカルにあるときだけ `--fix` で自動修正し、
#          それでも残ったエラーを decision: block でエージェントに渡す。
#
# 対象外（`--fix` だけ適用し、残エラーは渡さない）:
#   作業記録ファイル（config.sh の WORK_RECORD_*）と .gitignore 対象。
#   コミットされない一時ファイルの校正にトークンを使わない。
#
# stop_hook_active（block 直後の 2 回目の Stop）のときは、`--fix` は実行するが block は返さない。
#   Why not: 文体の混在など機械的に直せないエラーは、エージェントが判断して残す場合がある。
#            毎回 block すると往復が止まらないため、差し戻しは 1 回に限る。
#
# Why not: 以前は PostToolUse（format.sh）で編集のたびに textlint を実行していた。
#          1 ターンに同じ .md を何度も編集すると同じ残エラーが毎回コンテキストへ入った。
#          Stop で 1 回にまとめれば、残エラーの報告は 1 ターン 1 回になる。
#
# 出力:
#   残エラーなし・対象なし: 何も出さず exit 0
#   残エラーあり          : {"decision": "block", "reason": "ERROR: ..."} を stdout、exit 0
#
# 入力 : stdin の JSON（session_id, stop_hook_active）
# =============================================================================
INPUT=$(cat)

# Cursor 互換実行（cursor_version あり）は cursor/hooks.json のアダプタ側で処理済みのため通過する
# shellcheck source=../lib/cursor-compat.sh
source "$(dirname "$0")/../lib/cursor-compat.sh"
exit_if_cursor_payload "$INPUT"
# shellcheck source=../lib/edited-files.sh
source "$(dirname "$0")/../lib/edited-files.sh"
# shellcheck source=../lib/find-bin.sh
source "$(dirname "$0")/../lib/find-bin.sh"
HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../config.sh
source "$HOOKS_DIR/config.sh"

sid=$(jq -r '.session_id // ""' <<<"$INPUT")

files=$(edited_files_unprocessed "$sid" textlint | grep -E '\.md$' || true)
# 読み出し位置は実行前に進める。差し戻し後に再編集されたファイルは改めて記録される。
edited_files_mark_processed "$sid" textlint
[ -n "$files" ] || exit 0

# 作業記録ファイル・.gitignore 対象なら 0 を返す
_is_exempt() {
  local file="$1" repo_root rel_path wf wd
  git -C "$(dirname "$file")" rev-parse --git-dir >/dev/null 2>&1 || return 1
  git -C "$(dirname "$file")" check-ignore -q "$file" 2>/dev/null && return 0
  repo_root=$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null)
  rel_path="${file#"${repo_root}"/}"
  for wf in "${WORK_RECORD_FILES[@]}"; do
    [ "$rel_path" = "$wf" ] && return 0
  done
  for wd in "${WORK_RECORD_DIRS[@]}"; do
    [[ "$rel_path" == "$wd"/* ]] && return 0
  done
  return 1
}

remaining_all=""
while IFS= read -r file; do
  [ -n "$file" ] || continue
  # textlint がローカルに無いファイルは何もしない（ツール実在ゲート）
  bin=$(find_local_bin "$file" textlint) || continue
  # textlint は設定ファイルを cwd 基準で解決するため、見つけた node_modules の親で実行する
  textlint_root="${bin%/node_modules/.bin/textlint}"
  (cd "$textlint_root" && "$bin" --fix "$file" >/dev/null 2>&1)
  _is_exempt "$file" && continue
  # --fix で直らなかったエラーを収集する（終了コードではなく出力の有無で判定する）
  remaining=$(cd "$textlint_root" && "$bin" --format compact "$file" 2>&1 | grep -E 'line [0-9]+' | head -30)
  [ -n "$remaining" ] && remaining_all="${remaining_all}ファイル: ${file}\n${remaining}\n\n"
done <<<"$files"

[ -n "$remaining_all" ] || exit 0
# block 直後の再 Stop では差し戻さない（--fix の適用だけで終える）
stop_hook_active "$INPUT" && exit 0

emit_block "ERROR: textlint --fix で自動修正できないエラーが残っています。\nWHY: 文章ルールの違反はレビューで手戻りになります。hook は機械的に直せる範囲だけを修正しました。\nFIX: 下記の各行を確認し、該当箇所を Edit で修正してから作業を終えてください（ファイル全体の書き直しはしません）。\n\n${remaining_all}"
exit 0
