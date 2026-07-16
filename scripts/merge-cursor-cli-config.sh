#!/usr/bin/env bash
# cursor/cli-permissions.json / cli-statusline.json の内容を
# ~/.cursor/cli-config.json の permissions / statusLine だけに反映する。
# model・authInfo 等のマシン固有項目は保持する。

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
SHARED_PERMS="$DOTFILES_DIR/cursor/cli-permissions.json"
SHARED_STATUSLINE="$DOTFILES_DIR/cursor/cli-statusline.json"
TARGET="$HOME/.cursor/cli-config.json"

if [[ ! -f "$SHARED_PERMS" ]]; then
  echo "merge-cursor-cli-config: not found: $SHARED_PERMS" >&2
  echo "  先に scripts/sync-cursor-cli-permissions.sh を実行してください" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "merge-cursor-cli-config: jq が必要です" >&2
  exit 1
fi

mkdir -p "$(dirname "$TARGET")"

if [[ ! -f "$TARGET" ]]; then
  jq -nc '{version:1, permissions:{allow:[], deny:[]}}' >"$TARGET"
fi

SHARED_PERMS_JSON=$(jq '.permissions' "$SHARED_PERMS")

TMP=$(mktemp)
jq --argjson perms "$SHARED_PERMS_JSON" '.permissions = $perms' "$TARGET" >"$TMP"
mv "$TMP" "$TARGET"

if [[ -f "$SHARED_STATUSLINE" ]]; then
  STATUSLINE=$(jq '.statusLine' "$SHARED_STATUSLINE")
  TMP=$(mktemp)
  jq --argjson sl "$STATUSLINE" '.statusLine = $sl' "$TARGET" >"$TMP"
  mv "$TMP" "$TARGET"
  echo "[MERGE] statusLine → $TARGET"
fi

ALLOW_N=$(jq '.permissions.allow | length' "$TARGET")
DENY_N=$(jq '.permissions.deny | length' "$TARGET")
echo "[MERGE] $TARGET (allow: $ALLOW_N, deny: $DENY_N)"
