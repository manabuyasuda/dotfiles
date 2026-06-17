#!/usr/bin/env bash
# usage-guard.sh の回帰テスト
#
# 守りたい不変条件:
#   1. コンテキストは yellow / red のそれぞれでツール実行を deny する。
#   2. 同じ帯では一度しか deny しない（毎ツール止めると作業が進まない）。
#      コンテキストは帯が変われば（yellow→red、green→再上昇）再発火する。
#   3. コストでは deny しない。契約はサブスク（定額）でトークン使用量に応じた追加課金が
#      ないため、コストでツールを止める根拠がない。コストがどれだけ高くても、コンテキストが
#      green なら必ず通過する（コスト単独では止めない）。
#      → これは「コスト停止」が将来うっかり復活したら落ちる番人テスト（T1/T1c/T2b/T4b/T8e）。
#   4. キャッシュが無い（statusline 未実行）ときはフェイルオープンで通過する。
#   5. 閾値判定は statusline.sh 一箇所に集約されている（二重定義しない）。
#      → statusline.sh を高使用率の入力で実走させ、その生成キャッシュで deny されることを
#        end-to-end で確認する（T8）。コンテキスト閾値がズレれば T8 が落ちる。
#      → コストの「表示」用 cost_level 計算は statusline.sh に残す（停止トリガではない）。
#        T8-a / T8d はその計算が壊れていないことを確認する（usage-guard はこれを読まない）。
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

_assert_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    FAIL=$((FAIL + 1)); printf 'FAIL - %s\n       期待: 「%s」を含まない\n       実際: %s\n' "$desc" "$needle" "$haystack"
  else
    PASS=$((PASS + 1)); printf 'ok   - %s\n' "$desc"
  fi
}

# ---------------------------------------------------------------------------
# T1: cost が赤帯（level2）単独（ctx=green）では通過する。
#     サブスクなのでコストでは止めない。コスト停止が復活すればここが deny になって落ちる。
# ---------------------------------------------------------------------------
_write_cache t1 green 2
_assert_eq "T1 cost=赤帯(level2) 単独（ctx green）は通過" "$(_decision t1)" "none"

# ---------------------------------------------------------------------------
# T1c: cost が黄帯（level1）単独（ctx=green）でも通過する。
# ---------------------------------------------------------------------------
_write_cache t1c green 1
_assert_eq "T1c cost=黄帯(level1) 単独（ctx green）も通過" "$(_decision t1c)" "none"

# ---------------------------------------------------------------------------
# T2b: cost レベルが赤帯→赤帯*1.5→*2.0 と上がっても、ctx=green の間は段階発火せず通過し続ける。
#      （旧仕様はレベルごとに再 deny していた。コスト停止が復活すればここが落ちる）
# ---------------------------------------------------------------------------
_write_cache t2b green 2
_assert_eq "T2b-a level2（赤帯）は通過"       "$(_decision t2b)" "none"
_write_cache t2b green 3
_assert_eq "T2b-b level3（赤帯*1.5）も通過"   "$(_decision t2b)" "none"
_write_cache t2b green 5
_assert_eq "T2b-c level5（赤帯*2.5）も通過"   "$(_decision t2b)" "none"

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
# T4b: ctx=green なら cost が高レベルでも通過する（コスト単独で止めないことの明示的な番人）
# ---------------------------------------------------------------------------
_write_cache t4b green 5
_assert_eq "T4b ctx green なら高コスト(level5)でも通過" "$(_decision t4b)" "none"

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
# T7: コンテキスト red と高コスト（level2）が同時でも、deny の理由はコンテキストのみ。
#     コストは停止理由に含めない（コスト停止を撤去したことの確認）。
# ---------------------------------------------------------------------------
_write_cache t7 red 2
t7out=$(_reason t7)
_assert_contains    "T7-a deny 理由はコンテキストを含む"   "$t7out" "コンテキスト使用率"
_assert_not_contains "T7-b deny 理由にコストを含めない"    "$t7out" "累計コスト"

# ---------------------------------------------------------------------------
# T8: statusline.sh の実走で生成されたキャッシュで、コンテキスト超過なら deny される（end-to-end）。
#     total_cost_usd=25（=¥4,000 → 表示用 cost_level=2）, used_percentage=80（>75 → red）。
#     deny はコンテキスト（red）由来であって、コストは停止に関与しない。
# ---------------------------------------------------------------------------
printf '{"session_id":"t8","cost":{"total_cost_usd":25,"total_duration_ms":1000},"context_window":{"used_percentage":80,"context_window_size":200000}}' \
  | bash "$STATUSLINE" >/dev/null
_assert_eq      "T8-a statusline が表示用 cost_level=2 を書く（¥4,000=赤帯ちょうど）" \
                "$(jq -r '.cost_level // empty' "$TMPDIR/statusline-prev-t8" 2>/dev/null)" "2"
_assert_eq      "T8-b statusline が ctx_band=red を書く（used%=80>CTX_RED）" \
                "$(jq -r '.ctx_band // empty' "$TMPDIR/statusline-prev-t8" 2>/dev/null)" "red"
_assert_eq      "T8-c コンテキスト red で usage-guard が deny する" "$(_decision t8)" "deny"

# ---------------------------------------------------------------------------
# T8e: 高コストでもコンテキストが green なら通過する（end-to-end の判別ケース）。
#      total_cost_usd=25（cost_level=2）, used_percentage=40（<CTX_YELLOW → green）。
#      コスト停止が復活すればここが deny になって落ちる。
# ---------------------------------------------------------------------------
printf '{"session_id":"t8e","cost":{"total_cost_usd":25,"total_duration_ms":1000},"context_window":{"used_percentage":40,"context_window_size":200000}}' \
  | bash "$STATUSLINE" >/dev/null
_assert_eq      "T8e-a statusline が表示用 cost_level=2 を書く（高コスト）" \
                "$(jq -r '.cost_level // empty' "$TMPDIR/statusline-prev-t8e" 2>/dev/null)" "2"
_assert_eq      "T8e-b ctx_band=green（used%=40）" \
                "$(jq -r '.ctx_band // empty' "$TMPDIR/statusline-prev-t8e" 2>/dev/null)" "green"
_assert_eq      "T8e-c 高コスト×ctx green は通過（コスト単独で止めない）" "$(_decision t8e)" "none"

# ---------------------------------------------------------------------------
# T8d: コスト表示段階の end-to-end。total_cost_usd=50（=¥8,000=赤帯*2.5）→ 表示用 level5。
#      赤帯後の 0.5 刻み（COST_STEP_RATIO）が statusline.sh で正しく効くこと（表示は残す）。
# ---------------------------------------------------------------------------
printf '{"session_id":"t8d","cost":{"total_cost_usd":50,"total_duration_ms":1000},"context_window":{"used_percentage":10,"context_window_size":200000}}' \
  | bash "$STATUSLINE" >/dev/null
_assert_eq      "T8d statusline が表示用 cost_level=5 を書く（¥8,000=赤帯*2.5）" \
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
