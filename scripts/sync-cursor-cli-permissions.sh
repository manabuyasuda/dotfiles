#!/usr/bin/env bash
# claude/settings.json の permissions を Cursor 形式に変換し、
# cursor/cli-permissions.json を生成する。
#
# 変換ルール:
#   Bash(...)  → Shell(...)
#   Edit(...)  → Write(...)
#   Glob(...)  → そのまま（.env 等の列挙防止）
#   mcp__srv__tool → Mcp(srv:tool)
#   その他     → そのまま（Read, Write, Skill 等）

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
SRC="$DOTFILES_DIR/claude/settings.json"
OUT="$DOTFILES_DIR/cursor/cli-permissions.json"

if [[ ! -f "$SRC" ]]; then
  echo "sync-cursor-cli-permissions: not found: $SRC" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "sync-cursor-cli-permissions: jq が必要です" >&2
  exit 1
fi

convert_entry() {
  local entry="$1"
  case "$entry" in
    Bash\(*)
      printf 'Shell(%s' "${entry#Bash(}"
      ;;
    Edit\(*)
      printf 'Write(%s' "${entry#Edit(}"
      ;;
    Glob\(*)
      printf '%s' "$entry"
      ;;
    mcp__*__*)
      local rest="${entry#mcp__}"
      local server="${rest%%__*}"
      local tool="${rest#*__}"
      printf 'Mcp(%s:%s)' "$server" "$tool"
      ;;
    *)
      printf '%s' "$entry"
      ;;
  esac
}

mapfile -t ALLOW_RAW < <(jq -r '.permissions.allow[]?' "$SRC")
mapfile -t DENY_RAW < <(jq -r '.permissions.deny[]?' "$SRC")

ALLOW_JSON='[]'
for entry in "${ALLOW_RAW[@]}"; do
  [[ -z "$entry" ]] && continue
  if converted=$(convert_entry "$entry"); then
    ALLOW_JSON=$(jq -nc --argjson arr "$ALLOW_JSON" --arg e "$converted" '$arr + [$e]')
  fi
done

DENY_JSON='[]'
for entry in "${DENY_RAW[@]}"; do
  [[ -z "$entry" ]] && continue
  if converted=$(convert_entry "$entry"); then
    DENY_JSON=$(jq -nc --argjson arr "$DENY_JSON" --arg e "$converted" '$arr + [$e]')
  fi
done

mkdir -p "$(dirname "$OUT")"
jq -n \
  --argjson allow "$ALLOW_JSON" \
  --argjson deny "$DENY_JSON" \
  '{
    permissions: {
      allow: ($allow | unique),
      deny: ($deny | unique)
    }
  }' >"$OUT"

echo "[SYNC] $OUT ($(jq '.permissions.allow | length' "$OUT") allow, $(jq '.permissions.deny | length' "$OUT") deny)"
