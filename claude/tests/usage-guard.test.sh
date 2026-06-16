#!/usr/bin/env bash
# usage-guard.sh の回帰テスト
#
# 守りたい不変条件:
#   1. statusline.sh が red 帯をキャッシュに書いたら、usage-guard.sh はその種別
#      （cost / context）のツール実行を deny する。
#   2. 同じ red 帯では一度しか deny しない（毎ツール止めると作業が進まない）。
#      帯が red を外れたらフラグは復活し、再び red になれば再発火する。
#   3. コストとコンテキストが同時に red のときはコストを優先し、次の呼び出しで
#      コンテキストを出す（1呼び出し1メッセージ）。
#   4. キャッシュが無い（statusline 未実行）ときはフェイルオープンで通過する。
#   5. 閾値判定は statusline.sh 一箇所に集約されている（二重定義しない）。
#      → statusline.sh を高コスト入力で実走させ、その生成キャッシュで deny されることを
#        end-to-end で確認する（T8）。閾値ロジックがズレれば T8 が落ちる。
#
# キャッシュは ${TMPDIR}/statusline-prev-<session_id>、状態は usage-guard-<session_id>。
# TMPDIR を差し替えて隔離するので、実時計や本物のキャッシュに依存しない。
#
# 使い方: bash claude/tests/usage-guard.test.sh
# 終了コード 0=全テスト成功 / 1=失敗あり

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GUARD="$SCRIPT_DIR/../hooks/pre-tool-use/usage-guard.sh"
STATUSLINE="$SCRIPT_DIR/../statusline.sh"

TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT
export TMPDIR="$TEST_TMP"

PASS=0
FAIL=0

# statusline.sh と同じ命名でキャッシュを直接置く（帯だけを指定）
_write_cache() { # $1=session $2=ctx_band $3=cost_band
  jq -nc --arg x "$2" --arg c "$3" '{ctx_band:$x,cost_band:$c}' > "$TMPDIR/statusline-prev-$1"
}

# usage-guard.sh を1回実行し、stdout（JSON or 空）を返す
_run() { printf '{"session_id":"%s"}' "$1" | bash "$GUARD"; }

# permissionDecision を返す（出力なし＝通過は "none"）
_decision() {
  local out; out=$(_run "$1")
  [ -z "$out" ] && { echo "none"; return; }
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"'
}

# permissionDecisionReason を返す
_reason() {
  local out; out=$(_run "$1")
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""' 2>/dev/null
}

_assert_eq() {
  local desc="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1)); printf 'ok   - %s\n' "$desc"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL - %s\n       期待: %s\n       実際: %s\n' "$desc" "$expected" "$actual"
  fi
}

_assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    PASS=$((PASS + 1)); printf 'ok   - %s\n' "$desc"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL - %s\n       期待: 「%s」を含む\n       実際: %s\n' "$desc" "$needle" "$haystack"
  fi
}

# ---------------------------------------------------------------------------
# T1: cost が red の初回はコスト超過で deny する
# decision と reason はそれぞれ初回呼び出しで判定したいので別セッションにする
# （同一セッションだと1回目の deny で状態が「警告済み」になり2回目が発火しない）
# ---------------------------------------------------------------------------
_write_cache t1a green red
_assert_eq      "T1-a cost=red 初回は deny" "$(_decision t1a)" "deny"
_write_cache t1b green red
_assert_contains "T1-b deny 理由はコスト超過" "$(_reason t1b)" "累計コスト"

# ---------------------------------------------------------------------------
# T2: 同じ red 帯では2回目以降は通過する（毎ツール止めない）
# ---------------------------------------------------------------------------
_write_cache t2 green red
_decision t2 >/dev/null            # 1回目 deny（状態に red を記録）
_write_cache t2 green red
_assert_eq "T2 cost=red 2回目は通過" "$(_decision t2)" "none"

# ---------------------------------------------------------------------------
# T3: context が red の初回はコンテキスト超過で deny する
# ---------------------------------------------------------------------------
_write_cache t3a red green
_assert_eq      "T3-a ctx=red 初回は deny" "$(_decision t3a)" "deny"
_write_cache t3b red green
_assert_contains "T3-b deny 理由はコンテキスト超過" "$(_reason t3b)" "コンテキスト使用率"

# ---------------------------------------------------------------------------
# T4: 両方 green なら通過する
# ---------------------------------------------------------------------------
_write_cache t4 green green
_assert_eq "T4 両方 green は通過" "$(_decision t4)" "none"

# ---------------------------------------------------------------------------
# T5: red → green に戻ってから再び red になると再発火する（フラグ復活）
# ---------------------------------------------------------------------------
_write_cache t5 green red
_decision t5 >/dev/null            # 1回目 deny
_write_cache t5 green green
_decision t5 >/dev/null            # green でフラグクリア
_write_cache t5 green red
_assert_eq "T5 red→green→red で再発火する" "$(_decision t5)" "deny"

# ---------------------------------------------------------------------------
# T6: キャッシュが無ければフェイルオープンで通過する
# ---------------------------------------------------------------------------
_assert_eq "T6 キャッシュ無しは通過" "$(_decision t6_no_cache)" "none"

# ---------------------------------------------------------------------------
# T7: 両方 red はコスト優先 → 次の呼び出しでコンテキスト → その後は通過
# ---------------------------------------------------------------------------
_write_cache t7 red red
_assert_contains "T7-a 1回目はコスト優先" "$(_reason t7)" "累計コスト"
_write_cache t7 red red
_assert_contains "T7-b 2回目はコンテキスト" "$(_reason t7)" "コンテキスト使用率"
_write_cache t7 red red
_assert_eq       "T7-c 3回目は通過"        "$(_decision t7)" "none"

# ---------------------------------------------------------------------------
# T8: statusline.sh の実走で生成された red 帯キャッシュで deny される（end-to-end）
#     閾値判定が statusline.sh に集約されていることの保証。
#     total_cost_usd=25（=¥4,000 > ¥3,200 → red）, used_percentage=80（>75 → red）
# ---------------------------------------------------------------------------
printf '{"session_id":"t8","cost":{"total_cost_usd":25,"total_duration_ms":1000},"context_window":{"used_percentage":80,"context_window_size":200000}}' \
  | bash "$STATUSLINE" >/dev/null
GENERATED_COST_BAND=$(jq -r '.cost_band // empty' "$TMPDIR/statusline-prev-t8" 2>/dev/null)
_assert_eq      "T8-a statusline が cost_band=red を書く" "$GENERATED_COST_BAND" "red"
_assert_eq      "T8-b その帯で usage-guard が deny する"   "$(_decision t8)" "deny"

# ---------------------------------------------------------------------------
echo "----"
printf '成功 %d / 失敗 %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
