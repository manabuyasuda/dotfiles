#!/usr/bin/env bash
# session-start Cursor アダプタの回帰テスト
#
# 守りたい不変条件:
#   1. 初期化済みプロジェクトでは何も出力しない（本体 hook が沈黙するため、
#      アダプタも additional_context を返さない）。
#   2. 未初期化（package.json があるのに node_modules がない）プロジェクトでは
#      additional_context で未初期化を伝える。
#   3. git worktree の場合は、その事実も additional_context に含める。
#   4. 環境変数ファイルは作成されるが空のまま（ツール検出の書き出しは廃止済み。
#      復活したらここで検出する）。

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ADAPTER="$SCRIPT_DIR/../hooks/adapters/session-start.sh"
ROOT="/Users/manabu.yasuda/MY/dotfiles"
SID="cursor-session-start-test"
ENV_FILE="$HOME/.cursor/cache/hook-env/${SID}.env"

TEST_TMP=$(mktemp -d)

cleanup() { rm -f "$ENV_FILE"; rm -rf "$TEST_TMP"; }
trap cleanup EXIT

PASS=0
FAIL=0

_assert() {
  local desc="$1" cond="$2"
  if eval "$cond"; then
    PASS=$((PASS + 1)); printf 'ok   - %s\n' "$desc"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL - %s\n' "$desc"
  fi
}

_run() { # $1=cwd
  jq -nc --arg s "$SID" --arg c "$1" '{session_id:$s, cwd:$c}' | bash "$ADAPTER"
}

# --- T1: 初期化済みプロジェクト（dotfiles 本体）では何も出力しない ---
OUT=$(_run "$ROOT")
_assert "T1 初期化済みでは出力なし" '[ -z "$OUT" ]'
_assert "T2 環境変数ファイルが作成される" '[ -f "$ENV_FILE" ]'
_assert "T3 環境変数ファイルは空（ツール検出の書き出しは廃止済み）" '[ ! -s "$ENV_FILE" ]'

# --- T4: 未初期化プロジェクトでは additional_context で伝える ---
UNINIT="$TEST_TMP/uninit"
mkdir -p "$UNINIT"
echo '{}' > "$UNINIT/package.json"
OUT=$(_run "$UNINIT")
_assert "T4 未初期化で additional_context が返る" 'printf "%s" "$OUT" | jq -e ".additional_context" >/dev/null'
_assert "T5 未初期化の旨を含む" 'printf "%s" "$OUT" | jq -r ".additional_context" | grep -q "未初期化"'
_assert "T6 worktree ではない場合その旨を含まない" '! printf "%s" "$OUT" | jq -r ".additional_context" | grep -q "git worktree です"'

# --- T7: git worktree かつ未初期化の場合はその事実も含める ---
MAIN="$TEST_TMP/main"
WT="$TEST_TMP/wt"
git init -q "$MAIN"
git -C "$MAIN" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
git -C "$MAIN" worktree add -q "$WT" -b test-wt
echo '{}' > "$WT/package.json"
OUT=$(_run "$WT")
_assert "T7 worktree 未初期化で additional_context が返る" 'printf "%s" "$OUT" | jq -e ".additional_context" >/dev/null'
_assert "T8 worktree である旨を含む" 'printf "%s" "$OUT" | jq -r ".additional_context" | grep -q "git worktree です"'

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
