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
# WHY NOT: dirname を呼ばない（理由は hooks/README.md「外部コマンドを起動しない」）
_HOOK_DIR="${0%/*}"
[ "$_HOOK_DIR" = "$0" ] && _HOOK_DIR="."

INPUT=$(cat)

# Cursor 互換実行（cursor_version あり）は cursor/hooks.json のアダプタ側で処理済みのため通過する
# shellcheck source=../lib/cursor-compat.sh
source "$_HOOK_DIR/../lib/cursor-compat.sh"
exit_if_cursor_payload "$INPUT"
# shellcheck source=../lib/edited-files.sh
source "$_HOOK_DIR/../lib/edited-files.sh"
# shellcheck source=../lib/find-bin.sh
source "$_HOOK_DIR/../lib/find-bin.sh"
HOOKS_DIR="$(cd "$_HOOK_DIR/.." && pwd)"
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

# package.json の scripts から、textlint を呼ぶスクリプトの --config とその glob を集める。
# WHY: textlint が自力で探す設定ファイル名は .textlintrc / .textlintrc.json /
#      .textlintrc.js / .textlintrc.yml に限られる。用途ごとに設定を分けるリポジトリ
#      （例: .textlintrc.docs.json と .textlintrc.ui.json）では見つからず、
#      `== No rules found ==` を出して終了コード 0 で終わるため、検査が空振りしてしまう。
#      設定の在り処を知っているのは package.json のスクリプトなので、そこから取る。
# WHY NOT: `pnpm lint:text:fix` をそのまま実行しない。スクリプトの glob は
#          リポジトリ全体を対象にするため、このターンで編集していないファイルの指摘まで
#          エージェントへ渡り、Stop フックを編集ファイルだけに絞った設計が崩れてしまう。
# 出力: "<設定ファイル>\t<glob> <glob> ..." を1行ずつ。--config が無ければ何も出さない。
_textlint_configs() {
  local pkg="$1/package.json" script cfg rest tok globs
  [ -f "$pkg" ] || return 0
  while IFS= read -r script; do
    case "$script" in *textlint*) ;; *) continue;; esac
    [[ "$script" =~ --config[[:space:]]+([^[:space:]]+) ]] || continue
    cfg="${BASH_REMATCH[1]}"
    cfg="${cfg%\"}"; cfg="${cfg#\"}"
    # --config の後ろに並ぶ引数のうち、オプションでないものを glob とみなす
    rest="${script#*--config }"
    rest="${rest#* }"
    globs=""
    for tok in $rest; do
      case "$tok" in -*) continue;; esac
      tok="${tok%\"}"; tok="${tok#\"}"
      globs="$globs $tok"
    done
    printf '%s\t%s\n' "$cfg" "${globs# }"
  done < <(jq -r '.scripts // {} | .[]' "$pkg" 2>/dev/null)
}

# glob がファイルの相対パスに一致するか。
# WHY NOT: bash の [[ == ]] はブレース展開をせず、`**` も通常の `*` として扱う。
#          `{md,mdx}` は extglob の `@(md|mdx)` へ、`**/` は `*` へ置き換えて照合する。
#          `*` は `/` をまたいで一致するため、`components/*.md` は
#          `components/data-display/avatar.md` に一致する。
_glob_matches() {
  local rel="$1" glob="$2" pat
  pat="${glob//\*\*\//*}"
  pat="${pat//\*\*/*}"
  while [[ "$pat" == *\{*\}* ]]; do
    local head="${pat%%\{*}" body="${pat#*\{}" tail
    tail="${body#*\}}"; body="${body%%\}*}"
    pat="${head}@(${body//,/|})${tail}"
  done
  shopt -s extglob
  [[ "$rel" == $pat ]]
}

remaining_all=""
# 編集ファイルを textlint の実体（node_modules/.bin/textlint）ごとにまとめる。
# WHY NOT: ファイルごとに textlint を起動しない。textlint の所要時間はファイル数ではなく
#          起動回数に比例する（実測: 1ファイル1回で約1.2秒、46ファイルまとめて1回で1.675秒）。
#          1ファイルにつき --fix と残エラー収集で2回起動すると、24ファイルで Stop フックの
#          上限60秒に達し、エージェントへ結果を返せないままタイムアウトしてしまう。
roots=""
pairs=""
while IFS= read -r file; do
  [ -n "$file" ] || continue
  # textlint がローカルに無いファイルは何もしない（ツール実在ゲート）
  bin=$(find_local_bin "$file" textlint) || continue
  # textlint は設定ファイルを cwd 基準で解決するため、見つけた node_modules の親で実行する
  textlint_root="${bin%/node_modules/.bin/textlint}"
  pairs="${pairs}${textlint_root}	${file}\n"
  case "$roots" in *"|$textlint_root|"*) ;; *) roots="${roots}|$textlint_root|";; esac
done <<<"$files"

while IFS= read -r textlint_root; do
  [ -n "$textlint_root" ] || continue
  bin="$textlint_root/node_modules/.bin/textlint"
  root_files=$(printf '%b' "$pairs" | awk -F'\t' -v r="$textlint_root" '$1==r{print $2}')
  [ -n "$root_files" ] || continue

  # --fix は除外ファイルにも適用する（残エラーの報告だけを除くのが既存の設計）
  # 残エラーの収集は除外ファイルを外した集合で行う
  configs=$(_textlint_configs "$textlint_root")
  # 設定が1つも取れないリポジトリでは --config を付けずに実行する（既存の挙動）
  [ -n "$configs" ] || configs="	"

  config_count=$(printf '%s' "$configs" | grep -c . || true)
  while IFS=$'\t' read -r cfg globs; do
    fix_set=""; check_set=""
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      rel="${file#"${textlint_root}"/}"
      # glob の指定があるスクリプトは、一致するファイルだけを担当する。
      # 設定が1つだけのリポジトリでは glob に関係なく全ファイルを対象にする。
      if [ -n "$globs" ] && [ "$config_count" -gt 1 ]; then
        matched=1
        # WHY NOT: `for g in $globs` をそのまま書かない。クォートしない展開は
        #          パス名展開も行うため、`docs/**/*.md` がカレントディレクトリの
        #          実ファイル一覧へ置き換わり、照合の対象を取り違えてしまう。
        set -f
        # shellcheck disable=SC2086
        set -- $globs
        set +f
        for g in "$@"; do _glob_matches "$rel" "$g" && { matched=0; break; }; done
        [ $matched -eq 0 ] || continue
      fi
      fix_set="${fix_set}${file}\n"
      _is_exempt "$file" || check_set="${check_set}${file}\n"
    done <<<"$root_files"
    [ -n "$fix_set" ] || continue

    # shellcheck disable=SC2046
    (cd "$textlint_root" && "$bin" ${cfg:+--config "$cfg"} --fix $(printf '%b' "$fix_set") >/dev/null 2>&1)
    [ -n "$check_set" ] || continue
    # --fix で直らなかったエラーを収集する（終了コードではなく出力の有無で判定する）
    # WHY: --fix の出力は「直した指摘」だけを並べ、直せなかった指摘を含まない。
    #      さらに --fix は専用のフォーマッタを使うため --format compact を受け付けない。
    #      修正と検知で2回に分けるのは textlint の仕様による。
    # shellcheck disable=SC2046
    remaining=$(cd "$textlint_root" && "$bin" ${cfg:+--config "$cfg"} --format compact $(printf '%b' "$check_set") 2>&1 | grep -E 'line [0-9]+' | head -30)
    [ -n "$remaining" ] && remaining_all="${remaining_all}${remaining}\n\n"
  done <<<"$configs"
done <<<"$(printf '%s' "$roots" | tr '|' '\n' | awk 'NF' | awk '!seen[$0]++')"

[ -n "$remaining_all" ] || exit 0
# block 直後の再 Stop では差し戻さない（--fix の適用だけで終える）
stop_hook_active "$INPUT" && exit 0

emit_block "ERROR: textlint --fix で自動修正できないエラーが残っています。\nWHY: 文章ルールの違反はレビューで手戻りになります。hook は機械的に直せる範囲だけを修正しました。\nFIX: 下記の各行を確認し、該当箇所を Edit で修正してから作業を終えてください（ファイル全体の書き直しはしません）。\n\n${remaining_all}"
exit 0
