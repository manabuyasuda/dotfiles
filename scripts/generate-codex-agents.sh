#!/usr/bin/env bash
# claude/agents/*/SUBAGENT.md から codex/agents/*.toml を生成する。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$SCRIPT_DIR/generate-codex-agents.py"
