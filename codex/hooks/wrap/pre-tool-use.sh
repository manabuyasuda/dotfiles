#!/usr/bin/env bash
# wrap/pre-tool-use.sh — claude/hooks/pre-tool-use/* の Codex ラッパ（stdin をそのまま渡す）

set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/../lib" && pwd)"
# shellcheck source=../lib/codex-io.sh
source "$LIB_DIR/codex-io.sh"

HOOK_NAME="${1:-}"
if [[ -z "$HOOK_NAME" ]]; then
  echo "pre-tool-use wrap: hook name required" >&2
  exit 0
fi

codex_io_load_settings_env

HOOK="$(cursor_io_dotfiles_dir)/claude/hooks/pre-tool-use/${HOOK_NAME}"
if [[ ! -f "$HOOK" ]]; then
  echo "pre-tool-use wrap: hook not found: $HOOK" >&2
  exit 0
fi

INPUT=$(cat)

if [[ "$HOOK_NAME" == "bash-guard.sh" ]]; then
  INPUT=$(cursor_io_shell_inject_description_fallback "$INPUT")
fi

printf '%s' "$INPUT" | bash "$HOOK" 2>/dev/null || true
