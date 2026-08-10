#!/bin/bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPOSITORY_ROOT/scripts/setup-codex-rules.sh"
FIXTURE_RULE="$REPOSITORY_ROOT/codex/rules/deny-npm-pnpm-install.rules"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

assert_directory() {
  [[ -d "$1" && ! -L "$1" ]] || {
    echo "NG: expected a real directory: $1" >&2
    exit 1
  }
}

assert_regular_file() {
  [[ -f "$1" && ! -L "$1" ]] || {
    echo "NG: expected a regular file: $1" >&2
    exit 1
  }
}

assert_link_target() {
  local path="$1"
  local expected="$2"
  [[ -L "$path" ]] || {
    echo "NG: expected a symbolic link: $path" >&2
    exit 1
  }
  [[ "$(readlink "$path")" == "$expected" ]] || {
    echo "NG: unexpected link target for $path" >&2
    exit 1
  }
}

create_fixture() {
  local case_root="$1"
  mkdir -p "$case_root/dotfiles/codex/rules" "$case_root/home/.codex"
  cp "$FIXTURE_RULE" "$case_root/dotfiles/codex/rules/deny-npm-pnpm-install.rules"
}

run_setup() {
  local case_root="$1"
  bash "$SCRIPT" \
    "$case_root/dotfiles" \
    "$case_root/home/.codex/rules" \
    "$case_root/backup"
}

test_new_environment() {
  local case_root="$TEST_ROOT/new-environment"
  create_fixture "$case_root"

  run_setup "$case_root"

  assert_directory "$case_root/home/.codex/rules"
  [[ ! -e "$case_root/home/.codex/rules/default.rules" ]]
  assert_link_target \
    "$case_root/home/.codex/rules/deny-npm-pnpm-install.rules" \
    "$case_root/dotfiles/codex/rules/deny-npm-pnpm-install.rules"
}

test_legacy_link_with_default_rules() {
  local case_root="$TEST_ROOT/legacy-with-default"
  create_fixture "$case_root"
  printf '%s\n' 'prefix_rule(pattern=["git", "commit"], decision="allow")' \
    > "$case_root/dotfiles/codex/rules/default.rules"
  cp "$case_root/dotfiles/codex/rules/default.rules" "$case_root/expected-default.rules"
  ln -s "$case_root/dotfiles/codex/rules" "$case_root/home/.codex/rules"

  run_setup "$case_root"

  assert_directory "$case_root/home/.codex/rules"
  assert_regular_file "$case_root/home/.codex/rules/default.rules"
  cmp -s "$case_root/expected-default.rules" "$case_root/home/.codex/rules/default.rules"
  [[ ! -e "$case_root/dotfiles/codex/rules/default.rules" ]]
  assert_link_target \
    "$case_root/home/.codex/rules/deny-npm-pnpm-install.rules" \
    "$case_root/dotfiles/codex/rules/deny-npm-pnpm-install.rules"
}

test_legacy_link_without_default_rules() {
  local case_root="$TEST_ROOT/legacy-without-default"
  create_fixture "$case_root"
  ln -s "$case_root/dotfiles/codex/rules" "$case_root/home/.codex/rules"

  run_setup "$case_root"

  assert_directory "$case_root/home/.codex/rules"
  [[ ! -e "$case_root/home/.codex/rules/default.rules" ]]
}

test_rerun_preserves_local_rules() {
  local case_root="$TEST_ROOT/rerun"
  create_fixture "$case_root"
  mkdir -p "$case_root/home/.codex/rules"
  printf '%s\n' 'local approval' > "$case_root/home/.codex/rules/default.rules"

  run_setup "$case_root"
  run_setup "$case_root"

  assert_regular_file "$case_root/home/.codex/rules/default.rules"
  [[ "$(cat "$case_root/home/.codex/rules/default.rules")" == "local approval" ]]
  assert_link_target \
    "$case_root/home/.codex/rules/deny-npm-pnpm-install.rules" \
    "$case_root/dotfiles/codex/rules/deny-npm-pnpm-install.rules"
}

test_conflicting_managed_rule_is_backed_up() {
  local case_root="$TEST_ROOT/conflicting-managed-rule"
  create_fixture "$case_root"
  mkdir -p "$case_root/home/.codex/rules"
  printf '%s\n' 'local rule' > "$case_root/home/.codex/rules/deny-npm-pnpm-install.rules"

  run_setup "$case_root"

  [[ "$(cat "$case_root/backup/codex-rules/deny-npm-pnpm-install.rules")" == "local rule" ]]
  assert_link_target \
    "$case_root/home/.codex/rules/deny-npm-pnpm-install.rules" \
    "$case_root/dotfiles/codex/rules/deny-npm-pnpm-install.rules"
}

test_new_environment
test_legacy_link_with_default_rules
test_legacy_link_without_default_rules
test_rerun_preserves_local_rules
test_conflicting_managed_rule_is_backed_up

echo "OK: Codex rules setup preserves local state and links managed rules"
