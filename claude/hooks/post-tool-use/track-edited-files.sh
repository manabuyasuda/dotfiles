#!/usr/bin/env bash
# =============================================================================
# post-tool-use/track-edited-files.sh — 編集したファイルのパスを記録する
# =============================================================================
# フック  : PostToolUse（Edit / MultiEdit / Write）
# 役割   : 編集ファイルのパスをセッション単位の目印ファイルへ追記するだけ。
#          ツールは起動せず、出力もしない（0 トークン）。
#          整形・textlint・型検査は Stop の *-edited-files.sh が 1 ターン 1 回まとめて行う。
# Why not: 以前は編集のたびに format.sh / typecheck.sh がツールを起動していた。
#          1 ターンに 10 回編集すれば 10 回走り、実装途中のエラーまで毎回コンテキストへ
#          入っていた。記録と実行を分ければ、頻度は構造的に 1 ターン 1 回になる。
# 入力 : stdin の JSON（session_id, tool_input.file_path）
# =============================================================================
INPUT=$(cat)

# Cursor 互換実行（cursor_version あり）は cursor/hooks.json のアダプタ側で処理済みのため通過する
# shellcheck source=../lib/cursor-compat.sh
source "$(dirname "$0")/../lib/cursor-compat.sh"
exit_if_cursor_payload "$INPUT"
# shellcheck source=../lib/edited-files.sh
source "$(dirname "$0")/../lib/edited-files.sh"

file=$(jq -r '.tool_input.file_path // ""' <<<"$INPUT")
sid=$(jq -r '.session_id // ""' <<<"$INPUT")

[ -n "$file" ] || exit 0
[[ "$file" =~ \.(js|jsx|ts|tsx|md)$ ]] || exit 0

edited_files_record "$sid" "$file"
exit 0
