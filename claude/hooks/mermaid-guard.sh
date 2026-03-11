#!/bin/bash
# mermaid-guard.sh - Write/Edit PostToolUse hook
#
# .md ファイル内の Mermaid ブロックを検証する:
# 1. mmdc による構文チェック（パースエラー検出）
# 2. \n リテラル禁止（R01）

INPUT=$(cat)
FILE_PATH=$(jq -r '.tool_input.file_path // ""' <<< "$INPUT")

# .md ファイルでなければスキップ
if [[ "$FILE_PATH" != *.md ]]; then
  exit 0
fi

# ファイルが存在しなければスキップ
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

ERRORS=""
# mmdc は .mmd 単体ファイルを入力とする。.md 内の各コードブロックを
# 一時ディレクトリに block_1.mmd, block_2.mmd ... として書き出して渡す。
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

block_num=0
in_block=false
block_lines=()

# .md ファイルを1行ずつ読み、```mermaid〜``` の範囲を抽出する
while IFS= read -r line; do
  # ```mermaid を検出したらブロック開始
  if [[ "$line" =~ ^\`\`\`mermaid ]]; then
    in_block=true
    block_lines=()
    continue
  fi

  # ``` を検出したらブロック終了 → 一時 .mmd ファイルに書き出して検証
  if [[ "$line" == '```' ]] && [[ "$in_block" == true ]]; then
    in_block=false
    block_num=$((block_num + 1))
    tmp_file="$TMP_DIR/block_${block_num}.mmd"
    printf '%s\n' "${block_lines[@]}" > "$tmp_file"

    # --- 1. mmdc 構文チェック ---
    mmdc_out=$(mmdc -i "$tmp_file" -o "$TMP_DIR/out_${block_num}.svg" 2>&1)
    err_msg=$(grep -A 3 "^Error" <<< "$mmdc_out" | head -4)
    if [[ -n "$err_msg" ]]; then
      ERRORS="${ERRORS}[ブロック${block_num}] 構文エラー（mmdc）:
${err_msg}

"
    fi

    # --- 2. \n リテラルチェック（R01）---
    # grep -F で '\n'（バックスラッシュ+n の2文字）をリテラル検索
    if grep -qF '\n' "$tmp_file"; then
      ERRORS="${ERRORS}[ブロック${block_num}] R01: ラベル内に \n が含まれています。\n は使用禁止です。ラベルを短くするか、ノード・ステップを分割して対応してください。

"
    fi

    continue
  fi

  # ブロック内の行を蓄積
  if [[ "$in_block" == true ]]; then
    block_lines+=("$line")
  fi
done < "$FILE_PATH"

# エラーがあれば Claude にフィードバック
if [[ -n "$ERRORS" ]]; then
  jq -n --arg reason "Mermaid 検証エラーが見つかりました。修正してください:

${ERRORS}" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
fi
