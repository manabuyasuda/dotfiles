#!/usr/bin/env bash
# plan-guard Cursor アダプタの回帰テスト（代表ケース）

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ADAPTER="$SCRIPT_DIR/../hooks/adapters/plan-guard.sh"

ROOT=$(mktemp -d)
mkdir -p "$ROOT/explore" "$ROOT/plan" "$ROOT/src"
export TMPDIR="$ROOT/tmpstate"
mkdir -p "$TMPDIR"
SID="cursor-test-session"
STATE="$TMPDIR/plan-guard-$SID"
SESSION_START="$TMPDIR/session-start-$SID"
trap 'rm -rf "$ROOT"' EXIT

PASS=0
FAIL=0

# 基準時刻ファイルを 2020-01-01 に固定して作る。plan/ のファイルとの新旧を
# タイムスタンプの粒度に依存せず決めるため、現在時刻ではなく固定値を使う。
# これが無いと plan-guard はフェイルオープンし、T1 が deny にならない。
_reset() {
  rm -f "$STATE"
  rm -f "$ROOT"/plan/* 2>/dev/null
  : > "$SESSION_START"
  touch -t 202001010000 "$SESSION_START"
  true
}
_fill_plan() { printf '計画\n' > "$ROOT/plan/task.md"; }

_permission() {
  local json="$1"
  local out
  out=$(printf '%s' "$json" | bash "$ADAPTER")
  if [ -z "$out" ]; then echo "allow"; return; fi
  printf '%s' "$out" | jq -r '.permission // "allow"'
}

_write_json() {
  local path="$1"
  jq -nc --arg p "$path" --arg s "$SID" --arg c "$ROOT" \
    '{path:$p, session_id:$s, cwd:$c}'
}

_assert_eq() {
  local desc="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1)); printf 'ok   - %s\n' "$desc"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL - %s\n       期待: %s\n       実際: %s\n' "$desc" "$expected" "$actual"
  fi
}

_reset
_assert_eq "T1 plan 空・初回は deny" \
  "$(_permission "$(_write_json "$ROOT/src/app.ts")")" "deny"

_reset; _fill_plan
_assert_eq "T2 plan ありは allow" \
  "$(_permission "$(_write_json "$ROOT/src/app.ts")")" "allow"

_reset
_assert_eq "T3 plan/ への Write は allow" \
  "$(_permission "$(_write_json "$ROOT/plan/new.md")")" "allow"

_reset
_assert_eq "T4 session_id 無しは allow（フェイルオープン）" \
  "$(_permission "$(jq -nc --arg p "$ROOT/src/app.ts" --arg c "$ROOT" '{path:$p,cwd:$c}')")" "allow"

_reset
_assert_eq "T5 ルート外 /tmp は allow" \
  "$(_permission "$(jq -nc --arg p "/tmp/foo.ts" --arg s "$SID" --arg c "$ROOT" '{path:$p,session_id:$s,cwd:$c}')")" "allow"

# Cursor CLI は SessionStart を送らないため、実運用では基準時刻ファイルが無い。
# 基準が無いまま止めるとすべての編集をブロックするので、フェイルオープンさせる。
_reset; rm -f "$SESSION_START"
_assert_eq "T6 基準時刻ファイル無しは allow（フェイルオープン）" \
  "$(_permission "$(_write_json "$ROOT/src/app.ts")")" "allow"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
