#!/usr/bin/env bash
# push-to-main-guard Cursor アダプタの回帰テスト

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ADAPTER="$SCRIPT_DIR/../hooks/adapters/push-to-main-guard.sh"

TEST_TMP=$(mktemp -d)
MAIN_WT="$TEST_TMP/repo"
FEATURE_WT="$TEST_TMP/feature-wt"
cleanup() {
  git -C "$MAIN_WT" worktree remove --force "$FEATURE_WT" 2>/dev/null
  rm -rf "$TEST_TMP"
}
trap cleanup EXIT

git init -q -b main "$MAIN_WT"
git -C "$MAIN_WT" config user.email tester@example.com
git -C "$MAIN_WT" config user.name tester
git -C "$MAIN_WT" commit -q --allow-empty -m init
git -C "$MAIN_WT" worktree add -q -b feature/x "$FEATURE_WT" >/dev/null 2>&1
export CLAUDE_PROJECT_DIR="$MAIN_WT"

PASS=0
FAIL=0

_permission() {
  local json="$1"
  local out
  out=$(printf '%s' "$json" | bash "$ADAPTER")
  if [ -z "$out" ]; then echo "allow"; return; fi
  printf '%s' "$out" | jq -r '.permission // "allow"'
}

_push_json() {
  jq -nc --arg cwd "$1" --arg c "$2" '{command:$c, cwd:$cwd}'
}

_assert_eq() {
  local desc="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1)); printf 'ok   - %s\n' "$desc"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL - %s\n       期待: %s\n       実際: %s\n' "$desc" "$expected" "$actual"
  fi
}

_assert_eq "T1 feature worktree の git push は allow" \
  "$(_permission "$(_push_json "$FEATURE_WT" "git push")")" "allow"
_assert_eq "T2 main 作業ツリーの git push は deny" \
  "$(_permission "$(_push_json "$MAIN_WT" "git push")")" "deny"
_assert_eq "T3 PR 本文中の git push は allow（誤検知しない）" \
  "$(_permission "$(_push_json "$FEATURE_WT" 'gh pr create --body "see git push to main"')")" "allow"
_assert_eq "T4 git push origin main は deny" \
  "$(_permission "$(_push_json "$FEATURE_WT" "git push origin main")")" "deny"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
