#!/usr/bin/env bash
# plan-guard.sh の回帰テスト
#
# 守りたい不変条件:
#   1. 実装系編集（explore/plan/retrospective 以外への Edit/MultiEdit/Write）は、plan/ に
#      非空ファイルが無ければ deny する（計画を書かせる）。*.md も対象。
#   2. plan/・explore/・retrospective/ 配下への書き込みは常に対象外（計画ファイル自体を
#      作れないと無限ロックになるため）。
#   3. 発火モデルは fire-once: 一度通過するとセッション内では以後止めない。通過時に解除
#      フラグ（state ファイル）を書き、deny 時は書かない（計画を書くまで止め続ける）。
#   4. file_path / session_id が取れないときはフェイルオープン（通過）。
#
# 使い方: bash claude/tests/plan-guard.test.sh
# 終了コード 0=全テスト成功 / 1=失敗あり

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GUARD="${PLAN_GUARD_OVERRIDE:-$SCRIPT_DIR/../hooks/pre-tool-use/plan-guard.sh}"

PASS=0
FAIL=0

# 疑似プロジェクトルート（git 管理外 → hook は cwd フォールバックを使う）
ROOT=$(mktemp -d)
mkdir -p "$ROOT/explore" "$ROOT/plan" "$ROOT/retrospective" "$ROOT/src"
export TMPDIR="$ROOT/tmpstate"
mkdir -p "$TMPDIR"
trap 'rm -rf "$ROOT"' EXIT

SID="testsession"
STATE="$TMPDIR/plan-guard-$SID"

_reset_state() { rm -f "$STATE"; }
_set_state()   { printf 'cleared' > "$STATE"; }
_empty_plan()  { rm -f "$ROOT"/plan/* "$ROOT"/plan/.[!.]* 2>/dev/null; true; }
_fill_plan()   { printf '計画の中身です。十分な長さを持つ非空ファイル。\n' > "$ROOT/plan/task.md"; }
_state_exists() { [ -f "$STATE" ] && echo yes || echo no; }

# input JSON を組み立てる（file_path, session_id, cwd）
_input() {  # $1=tool_name $2=file_path
  jq -nc --arg t "$1" --arg f "$2" --arg s "$SID" --arg c "$ROOT" \
    '{tool_name:$t, session_id:$s, cwd:$c, tool_input:{file_path:$f}}'
}

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

# ---------------------------------------------------------------------------
# T1: 初回・plan 空・state 無 → deny（計画なしで実装着手をブロック）
# ---------------------------------------------------------------------------
_reset_state; _empty_plan
_assert_eq "T1 初回・plan 空 → deny" \
  "$(_decision "$(_input Write "$ROOT/src/app.ts")")" "deny"
_assert_eq "T1b deny 時は state を作らない（計画を書くまで止め続ける）" \
  "$(_state_exists)" "no"

# ---------------------------------------------------------------------------
# T2: 初回・plan 非空・state 無 → 通過 + 解除フラグ作成
# ---------------------------------------------------------------------------
_reset_state; _fill_plan
_assert_eq "T2 初回・plan 非空 → 通過" \
  "$(_decision "$(_input Write "$ROOT/src/app.ts")")" "none"
_assert_eq "T2b 通過時に state（解除フラグ）を作る" \
  "$(_state_exists)" "yes"

# ---------------------------------------------------------------------------
# T3: fire-once。state 有なら plan が空でも通過する（一度通れば以後止めない）
# ---------------------------------------------------------------------------
_reset_state; _set_state; _empty_plan
_assert_eq "T3 fire-once: 一度通過後は plan 空でも通過" \
  "$(_decision "$(_input Edit "$ROOT/src/app.ts")")" "none"

# ---------------------------------------------------------------------------
# T4: plan/ への書き込みは常に対象外 → 通過、解除フラグも作らない
# ---------------------------------------------------------------------------
_reset_state; _empty_plan
_assert_eq "T4 plan/ への書き込みは対象外 → 通過" \
  "$(_decision "$(_input Write "$ROOT/plan/new.md")")" "none"
_assert_eq "T4b 対象外パスは state を作らない（ゲート未解除のまま）" \
  "$(_state_exists)" "no"

# ---------------------------------------------------------------------------
# T5/T6: explore/・retrospective/ も対象外 → 通過
# ---------------------------------------------------------------------------
_reset_state; _empty_plan
_assert_eq "T5 explore/ は対象外 → 通過" \
  "$(_decision "$(_input Write "$ROOT/explore/scan.md")")" "none"
_reset_state; _empty_plan
_assert_eq "T6 retrospective/ は対象外 → 通過" \
  "$(_decision "$(_input Edit "$ROOT/retrospective/2026-06-17.md")")" "none"

# ---------------------------------------------------------------------------
# T7: 作業記録外の *.md も対象（ユーザー選択「作業記録以外すべて」）→ deny
# ---------------------------------------------------------------------------
_reset_state; _empty_plan
_assert_eq "T7 作業記録外の *.md も対象 → deny" \
  "$(_decision "$(_input Write "$ROOT/README.md")")" "deny"

# ---------------------------------------------------------------------------
# T8: file_path 無し → 通過（判定できないのでフェイルオープン）
# ---------------------------------------------------------------------------
_reset_state; _empty_plan
_assert_eq "T8 file_path 無しは通過" \
  "$(_decision "$(jq -nc --arg s "$SID" --arg c "$ROOT" '{tool_name:"Write",session_id:$s,cwd:$c,tool_input:{}}')")" "none"

# ---------------------------------------------------------------------------
# T9: session_id 無し → 通過（fire-once を追跡できないのでフェイルオープン）
# ---------------------------------------------------------------------------
_reset_state; _empty_plan
_assert_eq "T9 session_id 無しは通過" \
  "$(_decision "$(jq -nc --arg c "$ROOT" '{tool_name:"Write",cwd:$c,tool_input:{file_path:($c+"/src/app.ts")}}')")" "none"

# ---------------------------------------------------------------------------
# T10: MultiEdit も対象 → deny
# ---------------------------------------------------------------------------
_reset_state; _empty_plan
_assert_eq "T10 MultiEdit も対象 → deny" \
  "$(_decision "$(_input MultiEdit "$ROOT/src/lib.ts")")" "deny"

# ---------------------------------------------------------------------------
# T11: plan に空ファイル（0byte）のみ → deny（非空ファイルを要求）
#      .gitkeep 等のプレースホルダで「計画あり」と誤判定しないことを担保する。
# ---------------------------------------------------------------------------
_reset_state; _empty_plan; : > "$ROOT/plan/.gitkeep"
_assert_eq "T11 plan に空ファイルのみ → deny（非空を要求）" \
  "$(_decision "$(_input Write "$ROOT/src/app.ts")")" "deny"
_empty_plan

# ---------------------------------------------------------------------------
echo "----"
printf '成功 %d / 失敗 %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
