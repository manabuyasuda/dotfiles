#!/usr/bin/env bash
# bash-guard.sh / push-to-main-guard.sh の worktree 対応の回帰テスト
#
# 守りたい不変条件:
#   「commit / push の保護ブランチ判定は、いま作業している worktree のブランチで行う」
#   ブランチ判定は Claude Code が hook 入力で渡す .cwd を基準にする。
#   CLAUDE_PROJECT_DIR は worktree 切り替えに追従しない（起動時のプロジェクトルートを指したまま）ため、
#   これに依存すると worktree 上での commit / push が誤って保護ブランチ扱いされブロックされる
#   （このリポジトリで実際に発生した不具合）。
#
# このテストは CLAUDE_PROJECT_DIR=<main作業ツリー> をわざと設定した状態で実行する。
# hook が .cwd を見ていれば feature worktree の操作は通り、main 作業ツリーの操作は拒否される。
# もし CLAUDE_PROJECT_DIR を見る実装に戻ると、feature worktree の commit/push が deny になり T1 が落ちる。
#
# 使い方: bash claude/tests/hook-guard.test.sh
# 終了コード 0=全テスト成功 / 1=失敗あり

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BASH_GUARD="$SCRIPT_DIR/../hooks/pre-tool-use/bash-guard.sh"
PUSH_GUARD="$SCRIPT_DIR/../hooks/pre-tool-use/push-to-main-guard.sh"

# 隔離した一時 git リポジトリ（main 作業ツリー）と feature worktree を作る。
# 実運用と同じ「main の作業ツリー＋feature の worktree」構造を再現する。
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

# CLAUDE_PROJECT_DIR が main を指す「worktree 非追従」の状況をわざと作る。
# 正しい実装（.cwd 参照）ならこの汚染に引きずられない。
export CLAUDE_PROJECT_DIR="$MAIN_WT"

PASS=0
FAIL=0

# hook を実行し permissionDecision を返す（出力なし＝通過は "none"）
_decision() {
  local script="$1" json="$2" out
  # 通過（exit 0・出力なし）は jq に空入力となり評価できないため "none" に正規化する
  out=$(printf '%s' "$json" | bash "$script")
  [ -z "$out" ] && { echo "none"; return; }
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"'
}

# NETWORK_WRITE 判定の後段（ブランチ判定）まで到達させるため、description に必須項目を入れる。
_commit_json() {  # $1=cwd
  jq -nc --arg cwd "$1" \
    '{tool_input:{command:"git commit -m msg",description:"目的:検証 影響:なし 許可:常に 拒否:なし"},cwd:$cwd}'
}
_push_json() {    # $1=cwd
  jq -nc --arg cwd "$1" '{tool_input:{command:"git push"},cwd:$cwd}'
}

_assert_eq() {
  local desc="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1)); printf 'ok   - %s\n' "$desc"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL - %s\n       期待: %s\n       実際: %s\n' "$desc" "$expected" "$actual"
  fi
}

# ---------------------------------------------------------------------------
# T1: feature worktree 上の commit / push は通す
#     （CLAUDE_PROJECT_DIR=main でも .cwd を見るため誤ブロックしない）
# ---------------------------------------------------------------------------
_assert_eq "T1-a feature worktree の commit は ask（誤ブロックしない）" \
  "$(_decision "$BASH_GUARD" "$(_commit_json "$FEATURE_WT")")" "ask"
_assert_eq "T1-b feature worktree の push は通過" \
  "$(_decision "$PUSH_GUARD" "$(_push_json "$FEATURE_WT")")" "none"

# ---------------------------------------------------------------------------
# T2: main 作業ツリー上の commit / push は保護する（deny）
# ---------------------------------------------------------------------------
_assert_eq "T2-a main 作業ツリーの commit は deny" \
  "$(_decision "$BASH_GUARD" "$(_commit_json "$MAIN_WT")")" "deny"
_assert_eq "T2-b main 作業ツリーの push は deny" \
  "$(_decision "$PUSH_GUARD" "$(_push_json "$MAIN_WT")")" "deny"

# ---------------------------------------------------------------------------
echo "----"
printf '成功 %d / 失敗 %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
