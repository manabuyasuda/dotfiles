#!/usr/bin/env bash
# =============================================================================
# stop/format-edited-files.sh — このターンで編集した JS/TS を 1 回まとめて整形する
# =============================================================================
# フック  : Stop
# 役割   : track-edited-files.sh が記録した *.js / *.jsx / *.ts / *.tsx のうち
#          未処理のものを、実体のあるフォーマッターで整形する。
#          整形に成功したら何も出さない（0 トークン）。失敗したときだけ
#          decision: block で出力を返し、エージェントに原因の解消を求める。
#
# フォーマッター解決の優先順位（いずれも実体があるものだけ。lib/find-bin.sh）:
#   1. node_modules/.bin/biome
#   2. node_modules/.bin/oxfmt → PATH 上の oxfmt
#   3. node_modules/.bin/prettier → PATH 上の prettier
#   いずれも無ければそのファイルは何もしない。
#
# stop_hook_active（block 直後の 2 回目の Stop）のときは、整形は実行するが block は返さない。
#   Why not: 毎回 block すると 8 回連続で Claude Code が強制終了するまで往復が続く。
#            1 回差し戻して直らないなら、それ以上はユーザーの判断に委ねる。
#
# 出力:
#   成功・対象なし: 何も出さず exit 0
#   整形失敗      : {"decision": "block", "reason": "ERROR: ..."} を stdout、exit 0
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

sid=$(jq -r '.session_id // ""' <<<"$INPUT")

files=$(edited_files_unprocessed "$sid" format | grep -E '\.(js|jsx|ts|tsx)$' || true)
# 読み出し位置は実行前に進める。整形に失敗して差し戻しても、修正で再編集されたファイルは
# track-edited-files.sh が改めて記録するため、次の Stop で再び対象になる。
edited_files_mark_processed "$sid" format
[ -n "$files" ] || exit 0

failures=""
while IFS= read -r file; do
  [ -n "$file" ] || continue
  # 実行結果は各分岐の直後に exit_code へ退避する（if 文全体の終了状態に依存させない）
  if bin=$(find_local_bin "$file" biome); then
    output=$("$bin" check --write "$file" 2>&1); exit_code=$?
  elif bin=$(find_bin "$file" oxfmt); then
    output=$("$bin" --write "$file" 2>&1); exit_code=$?
  elif bin=$(find_bin "$file" prettier); then
    output=$("$bin" --write "$file" 2>&1); exit_code=$?
  else
    continue
  fi
  if [ "$exit_code" -ne 0 ]; then
    failures="${failures}ファイル: ${file}（${bin##*/}）\n${output}\n\n"
  fi
done <<<"$files"

[ -n "$failures" ] || exit 0
# block 直後の再 Stop では差し戻さない（整形の試行だけで終える）
stop_hook_active "$INPUT" && exit 0

emit_block "ERROR: フォーマッターによる整形に失敗したファイルがあります。\nWHY: 整形できないファイルは構文エラーを含んでいるか、フォーマッターの設定が不正な可能性があります。そのまま終えるとコミット時に同じエラーで止まります。\nFIX: 下記の出力を確認して原因を解消してから、作業を終えてください。\n\n${failures}"
exit 0
