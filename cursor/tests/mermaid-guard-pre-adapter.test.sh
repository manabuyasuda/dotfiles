#!/usr/bin/env bash
# mermaid-guard-pre Cursor アダプタの回帰テスト（代表ケース）

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ADAPTER="$SCRIPT_DIR/../hooks/adapters/mermaid-guard-pre.sh"

PASS=0
FAIL=0

_permission() {
  local json="$1"
  local out
  out=$(printf '%s' "$json" | bash "$ADAPTER")
  if [ -z "$out" ]; then echo "allow"; return; fi
  printf '%s' "$out" | jq -r '.permission // "allow"'
}

_assert_eq() {
  local desc="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1)); printf 'ok   - %s\n' "$desc"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL - %s\n       期待: %s\n       実際: %s\n' "$desc" "$expected" "$actual"
  fi
}

_bad_content() {
  jq -nc --arg c $'```mermaid\ngraph TD\n  A[一行目\\n二行目] --> B\n```' \
    '{path:"doc.md", content:$c}'
}

_bash_content() {
  jq -nc --arg c $'```bash\necho "a\\nb"\n```' \
    '{path:"doc.md", content:$c}'
}

_assert_eq "T1 mermaid 内 \\n は deny" \
  "$(_permission "$(_bad_content)")" "deny"
_assert_eq "T2 bash ブロック内 \\n は allow" \
  "$(_permission "$(_bash_content)")" "allow"
_assert_eq "T3 .txt は allow" \
  "$(_permission "$(jq -nc --arg c $'```mermaid\nA[x\\ny]\n```' '{path:"doc.txt", content:$c}')")" "allow"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
