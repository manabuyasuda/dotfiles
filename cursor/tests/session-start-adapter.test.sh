#!/usr/bin/env bash
# session-start Cursor アダプタの回帰テスト

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ADAPTER="$SCRIPT_DIR/../hooks/adapters/session-start.sh"
ROOT="/Users/manabu.yasuda/MY/dotfiles"
SID="cursor-session-start-test"
ENV_FILE="$HOME/.cursor/cache/hook-env/${SID}.env"

PASS=0
FAIL=0

cleanup() { rm -f "$ENV_FILE"; }
trap cleanup EXIT

_assert() {
  local desc="$1" cond="$2"
  if eval "$cond"; then
    PASS=$((PASS + 1)); printf 'ok   - %s\n' "$desc"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL - %s\n' "$desc"
  fi
}

OUT=$(jq -nc --arg s "$SID" --arg c "$ROOT" '{session_id:$s, cwd:$c}' | bash "$ADAPTER")

_assert "T1 additional_context が返る" '[ -n "$OUT" ]'
_assert "T2 additional_context フィールドがある" 'printf "%s" "$OUT" | jq -e ".additional_context" >/dev/null'
_assert "T3 環境変数ファイルが作成される" '[ -f "$ENV_FILE" ]'
_assert "T4 FORMATTER が書き出される" 'grep -q FORMATTER "$ENV_FILE"'

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
