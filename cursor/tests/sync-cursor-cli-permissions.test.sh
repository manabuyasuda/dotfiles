#!/usr/bin/env bash
# sync-cursor-cli-permissions.sh の変換結果を検証する

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
PERMS="$DOTFILES_DIR/cursor/cli-permissions.json"

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

# 最新を生成
"$DOTFILES_DIR/scripts/sync-cursor-cli-permissions.sh" >/dev/null

_assert "T1 allow が空でない" '[ "$(jq ".permissions.allow | length" "$PERMS")" -gt 0 ]'
_assert "T2 deny が空でない" '[ "$(jq ".permissions.deny | length" "$PERMS")" -gt 0 ]'
_assert "T3 Bash( が残っていない" '! jq -r ".permissions.allow[], .permissions.deny[]" "$PERMS" | grep -q "^Bash("'
_assert "T4 Shell( に変換されている" 'jq -r ".permissions.allow[]" "$PERMS" | grep -q "^Shell("'
_assert "T5 Mcp(figma: に変換されている" 'jq -r ".permissions.allow[]" "$PERMS" | grep -q "^Mcp(figma:"'
_assert "T6 deny に重複 Write がない" '[ "$(jq "[.permissions.deny[] | select(. == \"Write(**/.env*)\")] | length" "$PERMS")" -le 1 ]'
_assert "T7 deny に Glob(**/.env*) がある" '[ "$(jq "[.permissions.deny[] | select(. == \"Glob(**/.env*)\")] | length" "$PERMS")" -eq 1 ]'

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
