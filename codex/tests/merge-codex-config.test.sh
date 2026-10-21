#!/bin/bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPOSITORY_ROOT/scripts/merge-codex-config.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  echo "NG: $1" >&2
  exit 1
}

assert_count() {
  local file="$1"
  local pattern="$2"
  local expected="$3"
  local actual
  actual=$(grep -cxF -- "$pattern" "$file" || true)
  [[ "$actual" == "$expected" ]] || fail "expected $expected line(s) of '$pattern' in $file, got $actual"
}

create_fixture() {
  local case_root="$1"
  mkdir -p "$case_root/dotfiles/codex" "$case_root/dotfiles/scripts" "$case_root/home/.codex"
  cp "$SCRIPT" "$case_root/dotfiles/scripts/merge-codex-config.sh"
  cat >"$case_root/dotfiles/codex/config.toml" <<'EOF'
approvals_reviewer = "auto_review"

[tui]
status_line_use_colors = true

[mcp_servers.figma]
url = "https://mcp.figma.com/mcp"
EOF
}

run_merge() {
  local case_root="$1"
  HOME="$case_root/home" bash "$case_root/dotfiles/scripts/merge-codex-config.sh" >/dev/null
}

test_new_environment() {
  local case_root="$TEST_ROOT/new-environment"
  create_fixture "$case_root"

  run_merge "$case_root"

  cmp -s "$case_root/dotfiles/codex/config.toml" "$case_root/home/.codex/config.toml" \
    || fail "new environment should receive the dotfiles config as is"
}

test_preserves_codex_owned_sections_only() {
  local case_root="$TEST_ROOT/existing-environment"
  local target="$case_root/home/.codex/config.toml"
  create_fixture "$case_root"
  # /model と TUI が書き込んだ状態を再現する。figma は旧方式で実ファイルにだけあった配置。
  cat >"$target" <<'EOF'
model = "gpt-other"
model_reasoning_effort = "low"

[tui]
status_line_use_colors = false

[tui.model_availability_nux]
"gpt-6.1-sol" = 4

[projects."/path/to/repo"]
trust_level = "trusted"

[hooks.state]

[hooks.state."/home/.codex/hooks.json:stop:0:0"]
trusted_hash = "sha256:abc"
enabled = true

[mcp_servers.figma]
url = "https://mcp.figma.com/mcp"
EOF

  run_merge "$case_root"

  assert_count "$target" '[mcp_servers.figma]' 1
  assert_count "$target" '[tui]' 1
  assert_count "$target" 'status_line_use_colors = true' 1
  assert_count "$target" 'status_line_use_colors = false' 0
  assert_count "$target" '[tui.model_availability_nux]' 1
  assert_count "$target" '"gpt-6.1-sol" = 4' 1
  assert_count "$target" '[projects."/path/to/repo"]' 1
  assert_count "$target" 'trust_level = "trusted"' 1
  assert_count "$target" '[hooks.state]' 1
  assert_count "$target" 'trusted_hash = "sha256:abc"' 1
  assert_count "$target" 'enabled = true' 1
  assert_count "$target" 'model = "gpt-other"' 0
  assert_count "$target" 'model_reasoning_effort = "low"' 0
}

test_idempotent() {
  local case_root="$TEST_ROOT/idempotent"
  local target="$case_root/home/.codex/config.toml"
  create_fixture "$case_root"
  printf '[projects."/path/to/repo"]\ntrust_level = "trusted"\n' >"$target"

  run_merge "$case_root"
  cp "$target" "$case_root/first.toml"
  run_merge "$case_root"

  cmp -s "$case_root/first.toml" "$target" || fail "merging twice should not change the result"
}

# codex/config.toml の model を書かない理由は同ファイルのコメントを参照。
test_dotfiles_config_has_no_model() {
  local source="$REPOSITORY_ROOT/codex/config.toml"
  if grep -nE '^[[:space:]]*(model|model_reasoning_effort)[[:space:]]*=' "$source"; then
    fail "codex/config.toml must not set model or model_reasoning_effort (zsh/.zshrc の codex 関数で指定する)"
  fi
}

test_dotfiles_config_has_no_model
test_new_environment
test_preserves_codex_owned_sections_only
test_idempotent
echo "OK: merge-codex-config"
