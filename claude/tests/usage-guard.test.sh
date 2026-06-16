#!/usr/bin/env bash
# usage-guard.sh の回帰テスト
#
# 守りたい不変条件:
#   1. コンテキストは yellow / red のそれぞれでツール実行を deny する。
#      コストは yellow（level1）/ 赤帯（level2）以降、0.5 刻みの各レベルで deny する。
#   2. 同じ帯/レベルでは一度しか deny しない（毎ツール止めると作業が進まない）。
#      コンテキストは帯が変われば（yellow→red、green→再上昇）再発火する。
#      コストはレベルが上がるたび（赤帯→赤帯*1.5→*2.0…）一度ずつ再発火する。
#   3. コストとコンテキストが同時に閾値到達のときは1回の deny に両方の理由を連結する。
#   4. キャッシュが無い（statusline 未実行）ときはフェイルオープンで通過する。
#   5. 閾値判定は statusline.sh 一箇所に集約されている（二重定義しない）。
#      → statusline.sh を高コスト/高使用率の入力で実走させ、その生成キャッシュで deny
#        されることを end-to-end で確認する（T8）。閾値・刻みがズレれば T8 が落ちる。
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

# statusline.sh と同じ命名でキャッシュを直接置く（ctx 帯 と cost レベルを指定）
_write_cache() { # $1=session $2=ctx_band $3=cost_level
  jq -nc --arg x "$2" --arg cl "$3" '{ctx_band:$x,cost_level:$cl}' > "$TMPDIR/statusline-prev-$1"
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
# T1: cost が赤帯（level2）の初回はコスト超過で deny する
# decision と reason はそれぞれ初回呼び出しで判定したいので別セッションにする
# （同一セッションだと1回目の deny で状態が「警告済み」になり2回目が発火しない）
# ---------------------------------------------------------------------------
_write_cache t1a green 2
_assert_eq      "T1-a cost=赤帯(level2) 初回は deny" "$(_decision t1a)" "deny"
_write_cache t1b green 2
_assert_contains "T1-b deny 理由はコスト超過" "$(_reason t1b)" "累計コスト"

# ---------------------------------------------------------------------------
# T1c: cost が黄帯（level1）でも deny する（red を待たずに止める）
# ---------------------------------------------------------------------------
_write_cache t1c green 1
_assert_eq      "T1-c cost=黄帯(level1) でも deny" "$(_decision t1c)" "deny"
_write_cache t1d green 1
_assert_contains "T1-d 黄帯の理由はコスト超過" "$(_reason t1d)" "累計コスト"

# ---------------------------------------------------------------------------
# T2: 同じレベルでは2回目以降は通過する（毎ツール止めない）
# ---------------------------------------------------------------------------
_write_cache t2 green 2
_decision t2 >/dev/null            # 1回目 deny（状態に level2 を記録）
_write_cache t2 green 2
_assert_eq "T2 cost 同一レベルの2回目は通過" "$(_decision t2)" "none"

# ---------------------------------------------------------------------------
# T2b: レベルが上がるたびに段階的に再発火する（赤帯→赤帯*1.5→赤帯*2.0）
# ---------------------------------------------------------------------------
_write_cache t2b green 2
_decision t2b >/dev/null            # level2 で deny
_write_cache t2b green 3
_assert_eq "T2b-a level3（赤帯*1.5）で再 deny" "$(_decision t2b)" "deny"
_write_cache t2b green 3
_assert_eq "T2b-b 同じ level3 の2回目は通過"    "$(_decision t2b)" "none"
_write_cache t2b green 4
_assert_eq "T2b-c level4（赤帯*2.0）で再 deny" "$(_decision t2b)" "deny"

# ---------------------------------------------------------------------------
# T3: context が red の初回はコンテキスト超過で deny する
# ---------------------------------------------------------------------------
_write_cache t3a red 0
_assert_eq      "T3-a ctx=red 初回は deny" "$(_decision t3a)" "deny"
_write_cache t3b red 0
_assert_contains "T3-b deny 理由はコンテキスト超過" "$(_reason t3b)" "コンテキスト使用率"

# ---------------------------------------------------------------------------
# T3c: context が yellow でも deny する（red を待たずに早めに圧縮させる）
# ---------------------------------------------------------------------------
_write_cache t3c yellow 0
_assert_eq      "T3-c ctx=yellow でも deny" "$(_decision t3c)" "deny"

# ---------------------------------------------------------------------------
# T3d: yellow で止めた後、圧縮せず red まで上がったら red で再 deny する
# ---------------------------------------------------------------------------
_write_cache t3d yellow 0
_decision t3d >/dev/null            # yellow で deny
_write_cache t3d red 0
_assert_eq "T3d-a ctx yellow→red で red 帯でも再 deny" "$(_decision t3d)" "deny"
_write_cache t3d red 0
_assert_eq "T3d-b 同じ red 帯の2回目は通過"            "$(_decision t3d)" "none"

# ---------------------------------------------------------------------------
# T4: 下限（ctx=green / cost level0）は通過する
# ---------------------------------------------------------------------------
_write_cache t4 green 0
_assert_eq "T4 下限は通過" "$(_decision t4)" "none"

# ---------------------------------------------------------------------------
# T5: ctx red → green に戻ってから再び red になると再発火する（フラグ復活）
# ---------------------------------------------------------------------------
_write_cache t5 red 0
_decision t5 >/dev/null            # 1回目 deny
_write_cache t5 green 0
_decision t5 >/dev/null            # green でフラグクリア
_write_cache t5 red 0
_assert_eq "T5 ctx red→green→red で再発火する" "$(_decision t5)" "deny"

# ---------------------------------------------------------------------------
# T6: キャッシュが無ければフェイルオープンで通過する
# ---------------------------------------------------------------------------
_assert_eq "T6 キャッシュ無しは通過" "$(_decision t6_no_cache)" "none"

# ---------------------------------------------------------------------------
# T7: コストとコンテキストが同時に閾値到達なら1回の deny に両方の理由を連結する
# ---------------------------------------------------------------------------
_write_cache t7 red 2
t7out=$(_reason t7)                 # 1回だけ実行し、その理由を使い回す（2回目は警告済みで空）
_assert_contains "T7-a 同時発火はコストを含む"         "$t7out" "累計コスト"
_assert_contains "T7-b 同時発火はコンテキストも同じ文に含む" "$t7out" "コンテキスト使用率"
_write_cache t7 red 2
_assert_eq       "T7-c 2回目は両方とも警告済みで通過"  "$(_decision t7)" "none"

# ---------------------------------------------------------------------------
# T8: statusline.sh の実走で生成されたキャッシュで deny される（end-to-end）
#     閾値・刻みが statusline.sh に集約されていることの保証。
#     total_cost_usd=25（=¥4,000 > ¥3,200 → 赤帯 level2）, used_percentage=80（>75 → red）
# ---------------------------------------------------------------------------
printf '{"session_id":"t8","cost":{"total_cost_usd":25,"total_duration_ms":1000},"context_window":{"used_percentage":80,"context_window_size":200000}}' \
  | bash "$STATUSLINE" >/dev/null
_assert_eq      "T8-a statusline が cost_level=2 を書く（¥4,000=赤帯ちょうど）" \
                "$(jq -r '.cost_level // empty' "$TMPDIR/statusline-prev-t8" 2>/dev/null)" "2"
_assert_eq      "T8-b statusline が ctx_band=red を書く（used%=80>CTX_RED）" \
                "$(jq -r '.ctx_band // empty' "$TMPDIR/statusline-prev-t8" 2>/dev/null)" "red"
_assert_eq      "T8-c その帯で usage-guard が deny する" "$(_decision t8)" "deny"

# ---------------------------------------------------------------------------
# T8d: コスト段階の end-to-end。total_cost_usd=50（=¥8,000=赤帯*2.5）→ level5。
#      赤帯後の 0.5 刻み（COST_STEP_RATIO）が statusline.sh で正しく効くことを守る。
# ---------------------------------------------------------------------------
printf '{"session_id":"t8d","cost":{"total_cost_usd":50,"total_duration_ms":1000},"context_window":{"used_percentage":10,"context_window_size":200000}}' \
  | bash "$STATUSLINE" >/dev/null
_assert_eq      "T8d statusline が cost_level=5 を書く（¥8,000=赤帯*2.5）" \
                "$(jq -r '.cost_level // empty' "$TMPDIR/statusline-prev-t8d" 2>/dev/null)" "5"

# ---------------------------------------------------------------------------
# T9: 閾値の具体数値をフックのメッセージにハードコードしない（statusline.sh への一元化を維持）
#     閾値を変えてもメッセージがズレない構造を壊さないための番人。
#     auto-compact の 95% は Claude Code 仕様値（閾値ではない）なので対象外。
# ---------------------------------------------------------------------------
if grep -nE '75 ?%|50 ?%|¥?3,?200|¥?1,?600' "$GUARD" >/dev/null 2>&1; then
  FAIL=$((FAIL + 1))
  printf 'FAIL - T9 フックに閾値数値(75%%/50%%/3200/1600)がハードコードされている\n       検出: %s\n' \
    "$(grep -nE '75 ?%|50 ?%|¥?3,?200|¥?1,?600' "$GUARD")"
else
  PASS=$((PASS + 1)); printf 'ok   - T9 フックに閾値数値をハードコードしていない\n'
fi

# ---------------------------------------------------------------------------
# T10: 境界 — used%=74 は赤帯に入らず yellow。CTX 閾値が変数で正しく効くことを守る。
#      新仕様では yellow でも deny する（早めに圧縮させる）。
# ---------------------------------------------------------------------------
printf '{"session_id":"t10","cost":{"total_cost_usd":0.01,"total_duration_ms":1000},"context_window":{"used_percentage":74,"context_window_size":200000}}' \
  | bash "$STATUSLINE" >/dev/null
_assert_eq      "T10-a used%=74 は ctx_band=yellow（CTX_RED 直下は赤でない）" \
                "$(jq -r '.ctx_band // empty' "$TMPDIR/statusline-prev-t10" 2>/dev/null)" "yellow"
_assert_eq      "T10-b その黄帯では usage-guard は deny する" "$(_decision t10)" "deny"

# ---------------------------------------------------------------------------
# T10c: used%=40 は green（CTX_YELLOW 未満）で通過する。
# ---------------------------------------------------------------------------
printf '{"session_id":"t10c","cost":{"total_cost_usd":0.01,"total_duration_ms":1000},"context_window":{"used_percentage":40,"context_window_size":200000}}' \
  | bash "$STATUSLINE" >/dev/null
_assert_eq      "T10c-a used%=40 は ctx_band=green（CTX_YELLOW 未満）" \
                "$(jq -r '.ctx_band // empty' "$TMPDIR/statusline-prev-t10c" 2>/dev/null)" "green"
_assert_eq      "T10c-b その帯では usage-guard は通過" "$(_decision t10c)" "none"

# ---------------------------------------------------------------------------
echo "----"
printf '成功 %d / 失敗 %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
