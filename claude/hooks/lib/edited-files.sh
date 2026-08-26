#!/usr/bin/env bash
# =============================================================================
# lib/edited-files.sh — 「このターンで編集したファイル」の記録と読み出し（共有関数）
# =============================================================================
# PostToolUse の track-edited-files.sh が編集ファイルのパスを追記し、
# Stop の *-edited-files.sh がそれを読んで整形・textlint・型検査を 1 ターン 1 回にまとめる。
#
# 置き場所: $HOME/.claude/cache/edited-files/<session_id>/
#   files          … 編集ファイルのパス（1 行 1 件、追記のみ）
#   cursor.<name>  … Stop hook <name> が処理し終えた files の行数
#
# Why not: Stop hook から目印ファイルを削除する設計にしなかった。同じイベントの
#          hook は実行順に依存できないため、削除役が他の hook より先に走ると
#          読み損ねる。各 hook が自分の読み出し位置（cursor）だけを持てば、
#          実行順に依存せず、削除役も不要になる。
# 実行権限: 不要（source されるだけで直接実行しない）
# =============================================================================

EDITED_FILES_ROOT="${EDITED_FILES_ROOT:-$HOME/.claude/cache/edited-files}"

# edited_files_dir <session_id>
#   セッション用ディレクトリのパスを返す。session_id が空なら "default" を使う。
edited_files_dir() {
  local sid="${1:-default}"
  sid="${sid//\//_}"
  echo "$EDITED_FILES_ROOT/$sid"
}

# edited_files_record <session_id> <file>
#   編集ファイルのパスを追記する。あわせて 7 日以上前のセッション分を片付ける。
edited_files_record() {
  local dir
  dir="$(edited_files_dir "$1")"
  mkdir -p "$dir"
  printf '%s\n' "$2" >> "$dir/files"
  find "$EDITED_FILES_ROOT" -mindepth 1 -mtime +7 -delete 2>/dev/null || true
}

# edited_files_unprocessed <session_id> <name>
#   Stop hook <name> がまだ処理していないファイルを、重複を除き、存在するものだけ 1 行 1 件で返す。
#   読み出し位置は edited_files_mark_processed で進める（読むだけでは進めない）。
edited_files_unprocessed() {
  local dir cursor total
  dir="$(edited_files_dir "$1")"
  [ -f "$dir/files" ] || return 0
  cursor=0
  [ -f "$dir/cursor.$2" ] && cursor=$(cat "$dir/cursor.$2")
  total=$(wc -l < "$dir/files" | tr -d ' ')
  [ "$total" -gt "$cursor" ] || return 0
  tail -n +"$((cursor + 1))" "$dir/files" | awk '!seen[$0]++' | while IFS= read -r f; do
    [ -f "$f" ] && printf '%s\n' "$f"
  done
}

# edited_files_mark_processed <session_id> <name>
#   Stop hook <name> の読み出し位置を files の現在の行数まで進める。
edited_files_mark_processed() {
  local dir
  dir="$(edited_files_dir "$1")"
  [ -f "$dir/files" ] || return 0
  wc -l < "$dir/files" | tr -d ' ' > "$dir/cursor.$2"
}

# stop_hook_active <input_json>
#   Stop hook が block した直後の 2 回目の Stop なら 0 を返す（このときは差し戻さない）。
stop_hook_active() {
  printf '%s' "$1" | jq -e '.stop_hook_active == true' >/dev/null 2>&1
}

# emit_block <message>
#   ERROR/WHY/FIX 形式の本文で decision: block を返す（\n を改行として扱う）。
emit_block() {
  printf '%b' "$1" | python3 -c "import json,sys; print(json.dumps({'decision': 'block', 'reason': sys.stdin.read()}))"
}
