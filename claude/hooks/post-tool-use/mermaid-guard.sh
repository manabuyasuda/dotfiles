#!/usr/bin/env bash
# =============================================================================
# post-tool-use/mermaid-guard.sh — Mermaid ブロックの構文チェック（mmdc）
# =============================================================================
# フック  : PostToolUse（Edit / Write）
# 役割   : .md ファイル編集後に全 Mermaid ブロックを mmdc で構文チェックし、
#          エラーがあればエージェントに修正させる。
#
# 終了コード:
#   0  → 通過（.md 以外 / ファイルなし / 構文エラーなし）
#   2  → ハードブロック（構文エラーあり）
#
# 入力 : stdin の JSON（tool_input.file_path）
# 出力 : stdout の JSON（permissionDecision: "deny"）
# ログ  : $HOME/.claude/mermaid-guard.log
# =============================================================================

LOG_FILE="$HOME/.claude/mermaid-guard.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

# メッセージの JSON 化と長さの制限は lib/decision.sh が行う（ERRORS に改行や特殊文字があっても壊れない）
_deny() {
  hook_emit_decision deny PostToolUse "$1"
  exit 2
}

INPUT=$(cat)

# Cursor 互換実行（cursor_version あり）は cursor/hooks.json のアダプタ側で判定済みのため通過する
# shellcheck source=../lib/cursor-compat.sh
source "$(dirname "$0")/../lib/cursor-compat.sh"
# shellcheck source=../lib/decision.sh
source "$(dirname "$0")/../lib/decision.sh"
exit_if_cursor_payload "$INPUT"
FILE_PATH=$(jq -r '.tool_input.file_path // ""' <<< "$INPUT")

# .md 以外のファイルは Mermaid を含まないのでスキップ
[[ "$FILE_PATH" != *.md ]] && exit 0
# Write ツールは存在しないパスに書き込む場合があるため、ファイルが実在するか確認する
[[ ! -f "$FILE_PATH" ]] && exit 0

ERRORS=""
# mmdc への入力・出力を格納する一時ディレクトリ。EXIT 時に自動削除する。
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

block_num=0
in_block=false
block_lines=()

# ファイルを1行ずつ読み、```mermaid ... ``` ブロックを検出して mmdc で構文チェックする
while IFS= read -r line; do
  # ブロック開始: 行のリセットと in_block フラグを立てる
  if [[ "$line" =~ ^\`\`\`mermaid ]]; then
    in_block=true
    block_lines=()
    continue
  fi

  # ブロック終了: ブロック内容を一時ファイルに書き出して mmdc を実行する
  if [[ "$line" == '```' ]] && [[ "$in_block" == true ]]; then
    in_block=false
    block_num=$((block_num + 1))
    tmp_file="$TMP_DIR/block_${block_num}.mmd"
    printf '%s\n' "${block_lines[@]}" > "$tmp_file"

    mmdc_out=$(mmdc -i "$tmp_file" -o "$TMP_DIR/out_${block_num}.svg" 2>&1)
    # mmdc のエラー出力は "Error" で始まる行から最大4行。それ以外はノイズなので除外する。
    err_msg=$(grep -A 3 "^Error" <<< "$mmdc_out" | head -4)
    if [[ -n "$err_msg" ]]; then
      log "[${FILE_PATH##*/}] block${block_num} mmdc ERROR: $err_msg"
      ERRORS="${ERRORS}[ブロック${block_num}] 構文エラー（mmdc）:
${err_msg}

"
    fi

    continue
  fi

  [[ "$in_block" == true ]] && block_lines+=("$line")
done < "$FILE_PATH"

# 理由文は lib/decision.sh が1行へ潰し、上限文字数で切り詰める。エラーが複数あると
# 末尾の詳細は落ちるが、行番号ごとに整形して読ませるより、承認ダイアログが画面から
# 押し出されないことを優先する。全文は同じファイルを mmdc にかければ再取得できる。
if [[ -n "$ERRORS" ]]; then
  _deny "ERROR: Mermaid の構文エラーが見つかりました。WHY: 構文エラーはレンダリング失敗の原因になります。FIX: 以下のエラーを修正してください:

${ERRORS}"
fi

exit 0
