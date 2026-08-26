#!/usr/bin/env bash
# claude/CLAUDE.md から cursor/rules/global-instructions.mdc を生成する。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$SCRIPT_DIR/generate-cursor-rules.py"
