#!/usr/bin/env bash
# =============================================================================
# pre-tool-use/mermaid-guard.sh — Mermaid ブロック内の \n リテラルを書き込み前に検出
# =============================================================================
# フック  : PreToolUse（Edit / Write）
# 役割   : .md ファイルへの書き込み前に Mermaid ブロック内の \n リテラルを検出してブロックする。
#          ```mermaid ... ``` の範囲のみを検査し、bash 等の他コードブロックは対象外とする。
#
# 終了コード:
#   0  → 通過（.md 以外 / Edit・Write 以外 / \n リテラルなし）
#   2  → ハードブロック（Mermaid ブロック内に \n リテラルあり）
#
# 入力 : stdin の JSON（tool_name / tool_input.file_path / tool_input.new_string または tool_input.content）
# 出力 : stdout の JSON（permissionDecision: "deny"）
# =============================================================================

# jq --arg でメッセージをエスケープ（\n リテラルを含む文字列でも JSON が壊れない）
_deny() {
  jq -n --arg msg "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$msg}}'
  exit 2
}

INPUT=$(cat)
# tool_name / file_path / new_string / content を1回の jq でまとめて取得する
# （同一 stdin を最大4回 parse しない）。new_string / content は確実に改行を含むため、
# read（改行で切れる）ではなく NUL 区切り＋mapfile で分割する。
# 各フィールドを NUL 終端して連結し（join + 末尾 NUL）、末尾要素のズレを防ぐ。
mapfile -d '' -t _fields < <(
  jq -j '[.tool_name // "", .tool_input.file_path // "", .tool_input.new_string // "", .tool_input.content // ""]
         | join("\u0000") + "\u0000"' <<<"$INPUT"
)
TOOL_NAME="${_fields[0]:-}"
FILE_PATH="${_fields[1]:-}"
NEW_STRING="${_fields[2]:-}"
WRITE_CONTENT="${_fields[3]:-}"

# .md 以外のファイルは Mermaid を含まないのでスキップ
[[ "$FILE_PATH" != *.md ]] && exit 0

# ツール種別ごとに書き込み内容が格納されるフィールドが異なる
# Edit: new_string（置換後の文字列）/ Write: content（ファイル全体）
if [[ "$TOOL_NAME" == "Edit" ]]; then
  CONTENT="$NEW_STRING"
elif [[ "$TOOL_NAME" == "Write" ]]; then
  CONTENT="$WRITE_CONTENT"
else
  exit 0
fi

# ```mermaid ... ``` ブロック内の行のみを抽出して検査する
# （bash 等の他コードブロックを誤検知しないよう mermaid 限定で絞る）
MERMAID_CONTENT=$(echo "$CONTENT" | awk '/^```mermaid/{found=1; next} /^```/{found=0} found{print}')

if echo "$MERMAID_CONTENT" | grep -qF '\n'; then
  _deny "ERROR: Mermaid ラベル内に \\n が含まれています。WHY: \\n はレンダリングエラーの原因になります。FIX: ラベルを短くするか、ノードを分割してください。"
fi
