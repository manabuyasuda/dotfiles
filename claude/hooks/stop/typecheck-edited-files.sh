#!/usr/bin/env bash
# =============================================================================
# stop/typecheck-edited-files.sh — このターンで編集した TS の型エラーを 1 回まとめて報告する
# =============================================================================
# フック  : Stop
# 役割   : track-edited-files.sh が記録した *.ts / *.tsx のうち未処理のものがあれば、
#          ローカルの tsc で `--noEmit` を実行し、編集したファイルに関するエラー行だけを
#          decision: block でエージェントに渡す。
#
# 範囲の考え方:
#   tsc は tsconfig 単位でしか動かず、ファイル単位の実行はできない。そのため
#   実行はプロジェクト全体、報告は編集したファイルの行だけに絞る。
#   Why not: 全体のエラーをそのまま渡すと、編集と無関係なエラーがコンテキストを占める。
#            hook は作業した範囲だけを検知し、全体は lefthook / CI に任せる。
#   Why not: `--incremental` は付けない。付けるかどうかはリポジトリの tsconfig の
#            設定次第で、hook 側から制御しない。
#
# 実行ディレクトリ:
#   node_modules/.bin/tsc を見つけたディレクトリ（= tsconfig.json を置く一般的な位置）で実行する。
#   複数の tsc に解決された場合はディレクトリごとに 1 回ずつ実行する。
#   tsc がローカルに無ければ何もしない（ツール実在ゲート。`npx tsc` は使わない）。
#
# stop_hook_active（block 直後の 2 回目の Stop）のときは実行せず、block も返さない。
#   Why not: 型エラーを残す判断はエージェントとユーザーに委ねる。差し戻しは 1 回に限る。
#
# 出力:
#   エラーなし・対象なし: 何も出さず exit 0
#   エラーあり          : {"decision": "block", "reason": "ERROR: ..."} を stdout、exit 0
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

files=$(edited_files_unprocessed "$sid" typecheck | grep -E '\.(ts|tsx)$' || true)
# 読み出し位置は実行前に進める。差し戻し後に再編集されたファイルは改めて記録される。
edited_files_mark_processed "$sid" typecheck
[ -n "$files" ] || exit 0
# block 直後の再 Stop では tsc を実行しない（待ち時間と往復を増やさない）
stop_hook_active "$INPUT" && exit 0

# tsc の実行ディレクトリ（重複なし）を集める
roots=""
while IFS= read -r file; do
  [ -n "$file" ] || continue
  bin=$(find_local_bin "$file" tsc) || continue
  roots="${roots}${bin%/node_modules/.bin/tsc}"$'\n'
done <<<"$files"
roots=$(printf '%s' "$roots" | awk 'NF && !seen[$0]++')
[ -n "$roots" ] || exit 0

errors_all=""
while IFS= read -r root; do
  [ -n "$root" ] || continue
  # tsc はエラー行のパスを cwd からの相対パスで出すため、編集ファイルも同じ形に揃えて絞り込む
  patterns=$(printf '%s\n' "$files" | while IFS= read -r f; do
    case "$f" in "$root"/*) printf '%s\n' "${f#"$root"/}" ;; esac
  done)
  [ -n "$patterns" ] || continue
  output=$(cd "$root" && ./node_modules/.bin/tsc --noEmit --pretty false 2>&1)
  matched=$(printf '%s\n' "$output" | grep -F -f <(printf '%s\n' "$patterns") | head -30)
  [ -n "$matched" ] && errors_all="${errors_all}プロジェクト: ${root}\n${matched}\n\n"
done <<<"$roots"

[ -n "$errors_all" ] || exit 0

emit_block "ERROR: このターンで編集したファイルに TypeScript の型エラーがあります。\nWHY: 型エラーを残したまま終えると、コミット時や CI で同じエラーで止まります。hook は編集したファイルに関する行だけを報告しています（プロジェクト全体は lefthook / CI が検査します）。\nFIX: 下記の各行を確認し、該当箇所を修正してから作業を終えてください。\n\n${errors_all}"
exit 0
