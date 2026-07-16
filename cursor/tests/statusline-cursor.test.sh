#!/usr/bin/env bash
# cursor/statusline.sh の変換・キャッシュ書き込みテスト

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STATUSLINE="$SCRIPT_DIR/../statusline.sh"
PASS=0
FAIL=0

TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT
export TMPDIR="$TEST_TMP"
SID="cursor-statusline-test"

_assert() {
  local desc="$1" cond="$2"
  if eval "$cond"; then
    PASS=$((PASS + 1)); printf 'ok   - %s\n' "$desc"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL - %s\n' "$desc"
  fi
}

jq -nc \
  --arg s "$SID" \
  --arg m "Composer 2.5" \
  --arg c "/tmp/dotfiles" \
  '{
    session_id: $s,
    model: {display_name: $m},
    cwd: $c,
    context_window: {context_window_size: 200000, used_percentage: 80}
  }' | bash "$STATUSLINE" >/dev/null

CACHE="$TMPDIR/statusline-prev-$SID"
_assert "T1 キャッシュファイルが作成される" '[ -f "$CACHE" ]'
_assert "T2 ctx_band=red（80%）" '[[ "$(jq -r .ctx_band "$CACHE")" == "red" ]]'
_assert "T3 stdout が空でない" '[[ -n "$(jq -nc --arg s "$SID" --arg m "Composer 2.5" --arg c "/tmp" "{session_id:\$s,model:{display_name:\$m},cwd:\$c,context_window:{context_window_size:200000,used_percentage:40}}" | bash "$STATUSLINE")" ]]'

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
