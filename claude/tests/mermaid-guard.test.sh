#!/usr/bin/env bash
# mermaid-guard.sh の回帰テスト
#
# 守りたい不変条件:
#   1. .md への書き込み内容で、```mermaid ... ``` ブロック内に \n リテラルがあれば deny する。
#   2. mermaid ブロック外の \n（bash コードブロック等）は誤検知しない（通過）。
#   3. Edit は tool_input.new_string、Write は tool_input.content を読む。
#   4. tool_name / file_path / new_string / content を1回の jq でまとめて取り、NUL 区切り＋
#      mapfile で分割する。new_string / content は確実に改行を含むため、read（改行で切れる）で
#      分割するとフィールドがずれ、後ろの mermaid ブロックを取りこぼして deny を見逃す。
#      複数行内容の先頭が無関係な行で、後方に \n 入り mermaid ブロックがあるケースで
#      field-shift がないことを担保する。
#
# 使い方: bash claude/tests/mermaid-guard.test.sh
# 終了コード 0=全テスト成功 / 1=失敗あり

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GUARD="$SCRIPT_DIR/../hooks/pre-tool-use/mermaid-guard.sh"

PASS=0
FAIL=0

# hook を実行し permissionDecision を返す（出力なし＝通過は "none"）
_decision() {
  local json="$1" out
  out=$(printf '%s' "$json" | bash "$GUARD")
  [ -z "$out" ] && { echo "none"; return; }
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"'
}

_assert_eq() {
  local desc="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1)); printf 'ok   - %s\n' "$desc"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL - %s\n       期待: %s\n       実際: %s\n' "$desc" "$expected" "$actual"
  fi
}

# mermaid ブロック内に \n リテラルを含む content を組み立てる。
# jq --arg で \n リテラル（バックスラッシュ+n の2文字）を安全に渡す。
_mermaid_bad_content() {  # $1=tool_name $2=field(new_string|content)
  jq -nc --arg t "$1" --arg c $'```mermaid\ngraph TD\n  A[一行目\\n二行目] --> B\n```' \
    "{tool_name:\$t, tool_input:{file_path:\"doc.md\", $2:\$c}}"
}

# ---------------------------------------------------------------------------
# T1: Write の content の mermaid ブロック内に \n があれば deny
# ---------------------------------------------------------------------------
_assert_eq "T1 Write: mermaid 内 \\n を deny" \
  "$(_decision "$(_mermaid_bad_content Write content)")" "deny"

# ---------------------------------------------------------------------------
# T2: Edit の new_string の mermaid ブロック内に \n があれば deny
#     （Write の content ではなく new_string を読めていることの確認）
# ---------------------------------------------------------------------------
_assert_eq "T2 Edit: mermaid 内 \\n を deny" \
  "$(_decision "$(_mermaid_bad_content Edit new_string)")" "deny"

# ---------------------------------------------------------------------------
# T3: mermaid ブロック外の \n は誤検知しない（bash ブロック内の \n は通過）
# ---------------------------------------------------------------------------
_bash_block_content() {
  jq -nc --arg c $'```bash\necho "a\\nb"\n```' \
    '{tool_name:"Write", tool_input:{file_path:"doc.md", content:$c}}'
}
_assert_eq "T3 mermaid 外（bash ブロック）の \\n は通過" \
  "$(_decision "$(_bash_block_content)")" "none"

# ---------------------------------------------------------------------------
# T4: .md 以外は通過（拡張子チェック）
# ---------------------------------------------------------------------------
_assert_eq "T4 .md 以外は通過" \
  "$(_decision "$(jq -nc --arg c $'```mermaid\nA[x\\ny]\n```' '{tool_name:"Write", tool_input:{file_path:"doc.txt", content:$c}}')")" "none"

# ---------------------------------------------------------------------------
# T5: Edit / Write 以外のツールは通過
# ---------------------------------------------------------------------------
_assert_eq "T5 Read ツールは通過" \
  "$(_decision "$(jq -nc --arg c $'```mermaid\nA[x\\ny]\n```' '{tool_name:"Read", tool_input:{file_path:"doc.md", content:$c}}')")" "none"

# ---------------------------------------------------------------------------
# T6: 複数行内容でフィールドがずれない（field-shift なし）
#     先頭に無関係な複数行があり、後方の mermaid ブロックに \n がある。
#     content を read（改行で切れる）で取ると先頭行しか読めず mermaid を取りこぼし
#     deny を見逃す（none）。NUL+mapfile で全行読めていれば deny になる。
#       正: deny / 誤（field-shift）: deny 以外（none）
# ---------------------------------------------------------------------------
_multiline_mermaid_content() {
  jq -nc --arg c $'# 見出し\n\n本文の段落です。\n\n```mermaid\ngraph TD\n  A[ラベル\\n改行] --> B\n```\n\n後続の段落。' \
    '{tool_name:"Write", tool_input:{file_path:"doc.md", content:$c}}'
}
_assert_eq "T6 複数行内容でも後方 mermaid の \\n を検出して deny（field-shift なし）" \
  "$(_decision "$(_multiline_mermaid_content)")" "deny"

# ---------------------------------------------------------------------------
echo "----"
printf '成功 %d / 失敗 %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
