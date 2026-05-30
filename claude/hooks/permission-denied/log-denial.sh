#!/usr/bin/env bash
# =============================================================================
# permission-denied/log-denial.sh — オートモード拒否の記録（観測・監査）
# =============================================================================
# フック  : PermissionDenied（matcher なし＝全ツール。settings.json 側で登録）
# 役割   : オートモードの分類器がツール呼び出しを拒否したとき、その内容を
#          1行 JSON でログに追記する。後でまとめて集計し、autoMode.environment
#          や permissions の改善（誤検知・偽陰性の反映）に使う。
#          このフックはブロックできない（拒否は既に発生済み）。記録専用。
#
# stdin JSON フィールド（Claude Code が渡す）:
#   hook_event_name : "PermissionDenied"
#   permission_mode : 現在の権限モード（"auto" など）
#   tool_name       : 拒否されたツール名（"Bash" / "Edit" / "Write" など）
#   tool_input      : ツールへの入力（.command / .file_path など）
#   denial_reason   : 拒否理由。オートモード分類器なら "auto_mode_classifier"
#   session_id      : セッション識別子
#   cwd             : 作業ディレクトリ
#
# 出力先 : $HOME/.claude/logs/auto-mode-denials.log（JSON Lines）
# 依存ツール: jq
#
# 集計例 : jq -r '[.ts,.project,.tool,.summary]|@tsv' ~/.claude/logs/auto-mode-denials.log
#          同じ宛先が 2〜3 回出たら autoMode.environment への追加を検討する。
#
# 出典: https://code.claude.com/docs/en/hooks.md#permissiondenied
# =============================================================================

INPUT=$(cat)

denial_reason=$(echo "$INPUT" | jq -r '.denial_reason // ""')

# オートモード分類器による拒否のみ記録する（手動 deny 等は対象外）。
[ "$denial_reason" = "auto_mode_classifier" ] || exit 0

LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/auto-mode-denials.log"
mkdir -p "$LOG_DIR"

# tool_input から代表的な値を要約として取り出す（command > file_path > path > url > 全体）。
summary=$(echo "$INPUT" | jq -r '
  (.tool_input.command // .tool_input.file_path // .tool_input.path // .tool_input.url // (.tool_input | tojson))
  | tostring | .[0:200]')
project=$(basename "${CLAUDE_PROJECT_DIR:-$(echo "$INPUT" | jq -r '.cwd // ""')}")

echo "$INPUT" | jq -c \
  --arg ts "$(date '+%Y-%m-%dT%H:%M:%S%z')" \
  --arg project "$project" \
  --arg summary "$summary" '{
    ts: $ts,
    session: .session_id,
    mode: .permission_mode,
    project: $project,
    tool: .tool_name,
    summary: $summary,
    denial_reason: .denial_reason
  }' >> "$LOG_FILE"

# 記録専用のため再試行通知は行わない（デフォルト）。
# モデルに別手段での再試行を促したい場合は、exit 0 の前に次を出力する:
#   jq -n '{hookSpecificOutput:{hookEventName:"PermissionDenied",retry:true}}'
exit 0
