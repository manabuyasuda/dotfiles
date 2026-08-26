#!/usr/bin/env bash
# bash-guard Cursor アダプタの回帰テスト
#
# 使い方: bash cursor/tests/bash-guard-adapter.test.sh
# 終了コード 0=全テスト成功 / 1=失敗あり

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ADAPTER="$SCRIPT_DIR/../hooks/adapters/bash-guard.sh"

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
  if [ -z "$out" ]; then
    echo "none"
    return
  fi
  printf '%s' "$out" | jq -r '.permission // "none"'
}

_shell_json() {
  local cwd="$1" command="$2"
  jq -nc --arg cwd "$cwd" --arg c "$command" \
    '{command: $c, cwd: $cwd}'
}

_assert_eq() {
  local desc="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1))
    printf 'ok   - %s\n' "$desc"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL - %s\n       期待: %s\n       実際: %s\n' "$desc" "$expected" "$actual"
  fi
}

# READ: 通過
_assert_eq "T1 git status は allow（READ）" \
  "$(_permission "$(_shell_json "$FEATURE_WT" "git status")")" "allow"

# WRITE: 通過
_assert_eq "T2 mkdir は allow（WRITE）" \
  "$(_permission "$(_shell_json "$FEATURE_WT" "mkdir -p /tmp/foo")")" "allow"

# NETWORK_WRITE: ask（Cursor は description を送らないが、ask になることが /compact 幻覚の再発防止条件）
_assert_eq "T3 feature worktree の git commit は ask" \
  "$(_permission "$(_shell_json "$FEATURE_WT" "git commit -m msg")")" "ask"

# 保護ブランチ: main 上の commit は deny
_assert_eq "T4 main 作業ツリーの git commit は deny" \
  "$(_permission "$(_shell_json "$MAIN_WT" "git commit -m msg")")" "deny"

# worktree: CLAUDE_PROJECT_DIR=main でも .cwd を見て feature は誤ブロックしない
_assert_eq "T5 feature worktree（CLAUDE_PROJECT_DIR=main）の commit は ask" \
  "$(_permission "$(_shell_json "$FEATURE_WT" "git commit -m msg")")" "ask"

# バックスラッシュ改行（継続行）は判定材料にしない（deny を廃止済み。
# WRITE として通過する。復活したらここで検出する）
_assert_eq "T6 バックスラッシュ改行（mkdir）は通過" \
  "$(_permission "$(_shell_json "$FEATURE_WT" $'mkdir foo\\\nbar')")" "allow"

# 改行入り command でも field-shift しない（DESTRUCTIVE → ask）
_assert_eq "T7 改行入り rm は ask（field-shift なし）" \
  "$(_permission "$(_shell_json "$FEATURE_WT" $'rm foo\nrm bar')")" "ask"

# 改行入り commit + main cwd → deny
_assert_eq "T8 改行入り git commit + main cwd は deny" \
  "$(_permission "$(_shell_json "$MAIN_WT" $'git commit -m a\ngit commit -m b')")" "deny"

# npm install（パッケージ名なし）: bash-guard 本体は deny（GNU sed で検出可能な環境）
_assert_eq "T9 npm install（パッケージ名なし）は deny" \
  "$(_permission "$(_shell_json "$FEATURE_WT" "npm install")")" "deny"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
