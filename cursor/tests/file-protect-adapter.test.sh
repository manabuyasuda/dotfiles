#!/usr/bin/env bash
# file-protect Cursor アダプタの回帰テスト
#
# 使い方: bash cursor/tests/file-protect-adapter.test.sh
# 終了コード 0=全テスト成功 / 1=失敗あり

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ADAPTER="$SCRIPT_DIR/../hooks/adapters/file-protect.sh"

PASS=0
FAIL=0

_permission() {
  local json="$1"
  local out
  out=$(printf '%s' "$json" | bash "$ADAPTER")
  if [ -z "$out" ]; then
    echo "none"
    return
  fi
  printf '%s' "$out" | jq -r '.permission // "none"'
}

_assert_eq() {
  local desc="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1))
    printf 'ok   - %s\n' "$desc"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL - %s\n       期待: %s\n       実際: %s\n' "$desc" "$expected" "$actual"
  fi
}

# Cursor 形式（path トップレベル）
_assert_eq "T1 .env は deny（path）" \
  "$(_permission "$(jq -nc '{path:"/project/.env"}')")" "deny"

_assert_eq "T2 package-lock.json は deny" \
  "$(_permission "$(jq -nc '{path:"/project/package-lock.json"}')")" "deny"

_assert_eq "T3 src/foo.ts は allow" \
  "$(_permission "$(jq -nc '{path:"/project/src/foo.ts"}')")" "allow"

_assert_eq "T4 .git/config は deny" \
  "$(_permission "$(jq -nc '{path:"/project/.git/config"}')")" "deny"

_assert_eq "T5 secret.pem は deny" \
  "$(_permission "$(jq -nc '{path:"/project/certs/secret.pem"}')")" "deny"

# tool_input 形式（Claude 互換フィールド）
_assert_eq "T6 .env は deny（tool_input.path）" \
  "$(_permission "$(jq -nc '{tool_input:{path:"/project/.env.local"}}')")" "deny"

# hooks / settings は git 管理下で変更を追跡する（カナリア ask は廃止）
_assert_eq "T7 ~/.cursor/hooks.json は allow" \
  "$(_permission "$(jq -nc '{path:"/Users/me/.cursor/hooks.json"}')")" "allow"

_assert_eq "T8 ~/.cursor/hooks/adapters/foo.sh は allow" \
  "$(_permission "$(jq -nc '{path:"/Users/me/.cursor/hooks/adapters/foo.sh"}')")" "allow"

_assert_eq "T9 ~/.cursor/cli-config.json は allow" \
  "$(_permission "$(jq -nc '{path:"/Users/me/.cursor/cli-config.json"}')")" "allow"

# Claude hooks も引き続き ask
_assert_eq "T10 ~/.claude/settings.json は allow" \
  "$(_permission "$(jq -nc '{path:"/Users/me/.claude/settings.json"}')")" "allow"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
