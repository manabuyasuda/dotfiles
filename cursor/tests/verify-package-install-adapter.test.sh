#!/usr/bin/env bash
# verify-package-install Cursor アダプタの回帰テスト（代表ケース）

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ADAPTER="$SCRIPT_DIR/../hooks/adapters/verify-package-install.sh"
EMPTY_HOME=$(mktemp -d)
trap 'rm -rf "$EMPTY_HOME"' EXIT

PASS=0
FAIL=0

_permission() {
  local cmd="$1"
  local out
  out=$(HOME="$EMPTY_HOME" jq -nc --arg c "$cmd" '{command:$c}' | HOME="$EMPTY_HOME" bash "$ADAPTER")
  if [[ -z "$out" ]]; then
    echo "allow"
    return
  fi
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

_assert_eq "T1 npm install pkg@ver は deny" \
  "$(_permission "npm install lodash@4.17.21")" "deny"
_assert_eq "T2 npm ci は allow" \
  "$(_permission "npm ci")" "allow"
_assert_eq "T3 gh pr create 本文内の npm install は allow" \
  "$(_permission 'gh pr create --body "npm install lodash の説明"')" "allow"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
