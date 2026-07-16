#!/usr/bin/env bash
# cursor_io_dotfiles_dir が ~/.cursor/hooks 経由でも dotfiles ルートを返すことを検証する

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
LIB_IN_REPO="$DOTFILES_DIR/cursor/hooks/lib/cursor-io.sh"
LIB_VIA_CURSOR="$HOME/.cursor/hooks/lib/cursor-io.sh"

PASS=0
FAIL=0

_assert_eq() {
  local desc="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1))
    printf 'ok   - %s\n' "$desc"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL - %s\n       期待: %s\n       実際: %s\n' "$desc" "$expected" "$actual"
  fi
}

_assert_file() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    PASS=$((PASS + 1))
    printf 'ok   - %s\n' "$desc"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL - %s (not found: %s)\n' "$desc" "$path"
  fi
}

_dotfiles_dir_from() {
  local lib_path="$1"
  # shellcheck disable=SC1090
  source "$lib_path"
  cursor_io_dotfiles_dir
}

_assert_eq "T1 リポジトリ内 lib から dotfiles ルート" \
  "$(_dotfiles_dir_from "$LIB_IN_REPO")" "$DOTFILES_DIR"

if [[ -f "$LIB_VIA_CURSOR" ]]; then
  _assert_eq "T2 ~/.cursor/hooks 経由でも dotfiles ルート" \
    "$(_dotfiles_dir_from "$LIB_VIA_CURSOR")" "$DOTFILES_DIR"
else
  printf 'skip - T2 ~/.cursor/hooks/lib が無い\n'
fi

ROOT="$(_dotfiles_dir_from "$LIB_IN_REPO")"
_assert_file "T3 dangerous-guard.sh が解決できる" \
  "$ROOT/claude/hooks/pre-tool-use/dangerous-guard.sh"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
