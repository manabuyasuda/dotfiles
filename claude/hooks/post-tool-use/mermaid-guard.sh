#!/usr/bin/env bash
# =============================================================================
# post-tool-use/mermaid-guard.sh — Mermaid ブロックの検査（mmdc / \n リテラル）
# =============================================================================
# フック  : PostToolUse（Edit / Write）
# 役割   : .md ファイル編集後に全 Mermaid ブロックを検査し、
#          エラーがあればエージェントに修正させる。
#          検査の実体は lib/mermaid-check.sh にあり、lefthook の pre-commit
#          （scripts/check-mermaid.sh 経由）と同じ判定を使う。
#
# 終了コード:
#   0  → 通過（.md 以外 / ファイルなし / エラーなし）
#   2  → ハードブロック（エラーあり）
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
# shellcheck source=../lib/mermaid-check.sh
source "$(dirname "$0")/../lib/mermaid-check.sh"
exit_if_cursor_payload "$INPUT"
FILE_PATH=$(jq -r '.tool_input.file_path // ""' <<< "$INPUT")

ERRORS=$(mermaid_check_file "$FILE_PATH") && exit 0

log "[${FILE_PATH##*/}] $ERRORS"

# 理由文は lib/decision.sh が1行へ潰し、上限文字数で切り詰める。エラーが複数あると
# 末尾の詳細は落ちるが、行番号ごとに整形して読ませるより、承認ダイアログが画面から
# 押し出されないことを優先する。全文は同じファイルを mmdc にかければ再取得できる。
_deny "ERROR: Mermaid の記述に問題が見つかりました。WHY: 構文エラーや \\n リテラルはレンダリング失敗の原因になります。FIX: 以下を修正してください:

${ERRORS}"
