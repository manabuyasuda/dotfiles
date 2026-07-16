#!/usr/bin/env bash
# branch-guard Cursor アダプタの回帰テスト
#
# 守りたい不変条件:
#   編集対象パスが属するリポジトリのブランチで保護判定する（カレント cwd ではない）
#
# 使い方: bash cursor/tests/branch-guard-adapter.test.sh
# 終了コード 0=全テスト成功 / 1=失敗あり

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ADAPTER="$SCRIPT_DIR/../hooks/adapters/branch-guard.sh"

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
echo init >"$MAIN_WT/README.md"
git -C "$MAIN_WT" add README.md
git -C "$MAIN_WT" commit -q -m init
git -C "$MAIN_WT" worktree add -q -b feature/x "$FEATURE_WT" >/dev/null 2>&1

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

_write_json() {
  local path="$1"
  jq -nc --arg p "$path" '{path: $p}'
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

# main リポジトリ配下（main ブランチ）→ deny
_assert_eq "T1 main 作業ツリーのファイル編集は deny" \
  "$(_permission "$(_write_json "$MAIN_WT/README.md")")" "deny"

# feature worktree 配下 → allow
_assert_eq "T2 feature worktree のファイル編集は allow" \
  "$(_permission "$(_write_json "$FEATURE_WT/README.md")")" "allow"

# git 管理外 → allow
_assert_eq "T3 /tmp 配下は allow（git 管理外）" \
  "$(_permission "$(_write_json "/tmp/branch-guard-test.md")")" "allow"

# ~/.claude 配下（別リポジトリまたは git 管理外）→ allow
_assert_eq "T4 ~/.claude 配下は allow" \
  "$(_permission "$(_write_json "$HOME/.claude/CLAUDE.md")")" "allow"

# 新規ファイル（親ディレクトリは存在）feature worktree → allow
_assert_eq "T5 feature worktree の新規ファイルは allow" \
  "$(_permission "$(_write_json "$FEATURE_WT/src/new.ts")")" "allow"

# 新規ファイル main 作業ツリー → deny
_assert_eq "T6 main 作業ツリーの新規ファイルは deny" \
  "$(_permission "$(_write_json "$MAIN_WT/src/new.ts")")" "deny"

# path 空 → allow
_assert_eq "T7 path 空は allow" \
  "$(_permission "$(jq -nc '{}')")" "allow"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
