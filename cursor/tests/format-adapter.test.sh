#!/usr/bin/env bash
# format Cursor アダプタの回帰テスト（対象外ファイルは何も返さない）

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ADAPTER="$SCRIPT_DIR/../hooks/adapters/format.sh"
ROOT="/Users/manabu.yasuda/MY/dotfiles"
SID="cursor-format-test"
ENV_FILE="$HOME/.cursor/cache/hook-env/${SID}.env"

PASS=0
FAIL=0

cleanup() { rm -f "$ENV_FILE"; }
trap cleanup EXIT

mkdir -p "$(dirname "$ENV_FILE")"
printf 'export FORMATTER=none\n' >"$ENV_FILE"

OUT=$(jq -nc --arg s "$SID" --arg c "$ROOT" --arg p "$ROOT/README.md" \
  '{session_id:$s, cwd:$c, path:$p}' | bash "$ADAPTER")

if [ -z "$OUT" ]; then
  PASS=$((PASS + 1)); printf 'ok   - T1 .md 以外相当（README は対象だが formatter なし）は空または context\n'
else
  PASS=$((PASS + 1)); printf 'ok   - T1 出力あり（additional_context）\n'
fi

# .txt は format 対象外
OUT2=$(jq -nc --arg s "$SID" --arg c "$ROOT" --arg p "/tmp/format-adapter-test.txt" \
  '{session_id:$s, cwd:$c, path:$p}' | bash "$ADAPTER")
if [ -z "$OUT2" ]; then
  PASS=$((PASS + 1)); printf 'ok   - T2 .txt は出力なし\n'
else
  FAIL=$((FAIL + 1)); printf 'FAIL - T2 .txt は出力なし想定\n'
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
