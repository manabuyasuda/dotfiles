#!/usr/bin/env bash
# =============================================================================
# lib/mermaid-check.sh — .md ファイル内の Mermaid ブロックを検査する（共有関数）
# =============================================================================
# 用途   : ファイルの中身から ```mermaid ... ``` ブロックを取り出し、
#          (1) ラベル内の \n リテラル、(2) mmdc の構文エラー、の2つを検出する。
# 実行権限: 不要（source されるだけで直接実行しない）
#
# 参照元 : post-tool-use/mermaid-guard.sh（PostToolUse での検査）
#          scripts/check-mermaid.sh（lefthook の pre-commit での検査）
#
# WHY: Cursor CLI は PreToolUse / PostToolUse の hook イベントを送らないため、
#      hook だけに検査を置くと CLI では1件も働かない。コミット時の lefthook にも
#      同じ検査を置く必要があるが、実装を2か所に書くと片方だけが更新されて判定が
#      食い違う。判定の実体をこのファイル1つに置き、hook と lefthook の双方から
#      呼ぶことで、情報源を1つに保つ。
#
# mermaid_check_file <file>
#   検査結果のエラー文を stdout へ出す。エラーがあれば 1、なければ 0 を返す。
#   .md 以外・存在しないファイル・mmdc が無い環境では検査せず 0 を返す。
# =============================================================================

mermaid_check_file() {
  local file="$1"
  [[ "$file" != *.md ]] && return 0
  [[ ! -f "$file" ]] && return 0

  local errors="" tmp_dir block_num=0 in_block=false line tmp_file mmdc_out err_msg
  local -a block_lines=()

  tmp_dir=$(mktemp -d)

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^\`\`\`mermaid ]]; then
      in_block=true
      block_lines=()
      continue
    fi

    if [[ "$line" == '```' ]] && [[ "$in_block" == true ]]; then
      in_block=false
      block_num=$((block_num + 1))
      tmp_file="$tmp_dir/block_${block_num}.mmd"
      printf '%s\n' "${block_lines[@]}" > "$tmp_file"

      # \n リテラル（バックスラッシュ+n の2文字）はレンダリングエラーの原因になるが、
      # mmdc は構文エラーとして扱わないため別に検出する。
      if grep -qF '\n' "$tmp_file"; then
        errors="${errors}[ブロック${block_num}] ラベル内に \\n リテラルがあります。ラベルを短くするか、ノードを分割してください。
"
      fi

      if command -v mmdc &>/dev/null; then
        mmdc_out=$(mmdc -i "$tmp_file" -o "$tmp_dir/out_${block_num}.svg" 2>&1)
        # mmdc のエラー出力は "Error" で始まる行から最大4行。それ以外はノイズなので除外する。
        err_msg=$(grep -A 3 "^Error" <<< "$mmdc_out" | head -4)
        if [[ -n "$err_msg" ]]; then
          errors="${errors}[ブロック${block_num}] 構文エラー（mmdc）:
${err_msg}

"
        fi
      fi

      continue
    fi

    [[ "$in_block" == true ]] && block_lines+=("$line")
  done < "$file"

  rm -rf "$tmp_dir"

  if [[ -n "$errors" ]]; then
    printf '%s' "$errors"
    return 1
  fi
  return 0
}
