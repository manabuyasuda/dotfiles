#!/usr/bin/env bash
# check-gh-account Cursor アダプタの回帰テスト

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ADAPTER="$SCRIPT_DIR/../hooks/adapters/check-gh-account.sh"

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

_assert_eq "T1 gh 以外は allow" \
  "$(_permission "$(jq -nc '{command:"git status"}')")" "allow"

_assert_eq "T2 引用符内の gh は allow（誤検知しない）" \
  "$(_permission "$(jq -nc '{command:"echo \"gh pr list\""}')")" "allow"

# gh auth switch はスキップ（アクティブアカウントに依存するため allow 想定）
_assert_eq "T3 gh auth switch は allow" \
  "$(_permission "$(jq -nc '{command:"gh auth switch --user someone"}')")" "allow"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
