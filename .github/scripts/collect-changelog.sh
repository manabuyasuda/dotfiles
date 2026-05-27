#!/usr/bin/env bash
set -euo pipefail

LAST_VERSION="${1:-}"
SRC="https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"

curl -fsSL "$SRC" -o CHANGELOG.md

latest=$(grep -m1 -E '^## ' CHANGELOG.md | sed 's/^## //')
if [[ -n "$latest" && ! "$latest" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error::Unexpected version format: ${latest}"
  exit 1
fi
if [[ -z "$latest" || "$latest" == "$LAST_VERSION" ]]; then
  echo "has_update=false" >>"$GITHUB_OUTPUT"
  exit 0
fi

mapfile -t new < <(awk -v last="$LAST_VERSION" '
  /^## /{ v=$2; if (last!="" && v==last) exit; print v }' CHANGELOG.md)

if [[ -z "$LAST_VERSION" || ${#new[@]} -eq 0 || ${#new[@]} -gt 20 ]]; then
  new=("$latest")
fi

for v in "${new[@]}"; do
  awk -v ver="$v" '
    $0=="## " ver {f=1; print; next}
    /^## /{f=0}
    f' CHANGELOG.md
  echo
done

echo "has_update=true" >>"$GITHUB_OUTPUT"
echo "latest=${latest}" >>"$GITHUB_OUTPUT"
