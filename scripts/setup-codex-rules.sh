#!/bin/bash
set -euo pipefail

DOTFILES_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
CODEX_RULES_DIR="${2:-$HOME/.codex/rules}"
BACKUP_DIR="${3:-$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)}"
MANAGED_RULES=(
  "deny-npm-pnpm-install.rules"
)

SOURCE_RULES_DIR="$DOTFILES_DIR/codex/rules"

if [[ ! -d "$SOURCE_RULES_DIR" ]]; then
  echo "error: Codex rules directory not found: $SOURCE_RULES_DIR" >&2
  exit 1
fi

backup_existing_path() {
  local path="$1"
  local backup_path="$BACKUP_DIR/codex-rules/$(basename "$path")"

  mkdir -p "$(dirname "$backup_path")"
  mv "$path" "$backup_path"
  echo "[BACKUP] $path -> $backup_path"
}

migrate_legacy_rules_link() {
  if [[ ! -L "$CODEX_RULES_DIR" ]]; then
    return
  fi

  local current_target
  current_target="$(readlink "$CODEX_RULES_DIR")"
  if [[ "$current_target" != "$SOURCE_RULES_DIR" ]]; then
    echo "error: unexpected ~/.codex/rules link target: $current_target" >&2
    echo "expected: $SOURCE_RULES_DIR" >&2
    exit 1
  fi

  local source_default="$SOURCE_RULES_DIR/default.rules"
  local temporary_dir=""
  local temporary_default=""

  if [[ -e "$source_default" || -L "$source_default" ]]; then
    if [[ ! -f "$source_default" || -L "$source_default" ]]; then
      echo "error: default.rules must be a regular file: $source_default" >&2
      exit 1
    fi
    temporary_dir="$(mktemp -d)"
    temporary_default="$temporary_dir/default.rules"
    cp -p "$source_default" "$temporary_default"
  fi

  unlink "$CODEX_RULES_DIR"
  mkdir -p "$CODEX_RULES_DIR"

  if [[ -n "$temporary_default" ]]; then
    cp -p "$temporary_default" "$CODEX_RULES_DIR/default.rules"
    if ! cmp -s "$source_default" "$CODEX_RULES_DIR/default.rules"; then
      echo "error: failed to preserve default.rules during migration" >&2
      exit 1
    fi
    unlink "$source_default"
    rm -r "$temporary_dir"
    echo "[MIGRATE] $source_default -> $CODEX_RULES_DIR/default.rules"
  fi

  echo "[MIGRATE] replaced directory link with local directory: $CODEX_RULES_DIR"
}

link_managed_rule() {
  local rule_name="$1"
  local source="$SOURCE_RULES_DIR/$rule_name"
  local destination="$CODEX_RULES_DIR/$rule_name"

  if [[ ! -f "$source" ]]; then
    echo "error: managed Codex rule not found: $source" >&2
    exit 1
  fi

  if [[ -L "$destination" ]] && [[ "$(readlink "$destination")" == "$source" ]]; then
    echo "[OK] linked: $destination"
    return
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    backup_existing_path "$destination"
  fi

  ln -s "$source" "$destination"
  echo "[LINK] $destination -> $source"
}

migrate_legacy_rules_link

if [[ -e "$CODEX_RULES_DIR" && ! -d "$CODEX_RULES_DIR" ]]; then
  backup_existing_path "$CODEX_RULES_DIR"
fi
mkdir -p "$CODEX_RULES_DIR"

for managed_rule in "${MANAGED_RULES[@]}"; do
  link_managed_rule "$managed_rule"
done
