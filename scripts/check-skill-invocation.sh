#!/bin/bash
# スキルの自動起動を止める指定が、Claude Code / Cursor 用と Codex 用で
# 一致していることを検証する。
#
# 背景: スキルの自動起動は 2 ファイルで決まる。SKILL.md の frontmatter
# `disable-model-invocation: true` が Claude Code と Cursor に効き、
# agents/openai.yaml の `policy.allow_implicit_invocation: false` が Codex に効く。
# Codex は frontmatter を解釈しないため、片方だけを書くと CLI によって
# 自動起動する / しないが分かれる。2026-10-09 に x-japanese-writing-review が
# この状態（Codex だけ自動起動できる）になっていたことが目視で判明した。
# 人の照合に頼らず pre-commit / CI で機械的に検出するためのチェック。
#
# 不変条件:
#   claude/skills/<skill>/ ごとに、次の 2 つが一致していなければならない。
#     - SKILL.md に `disable-model-invocation: true` がある
#     - agents/openai.yaml に `allow_implicit_invocation: false` がある

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="${1:-$DOTFILES_DIR/claude/skills}"

if [[ ! -d "$SKILLS_DIR" ]]; then
  echo "error: not found: $SKILLS_DIR" >&2
  exit 1
fi

drift=()

for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
  [[ -f "$skill_md" ]] || continue
  skill_dir="$(dirname "$skill_md")"
  skill_name="$(basename "$skill_dir")"
  openai_yaml="$skill_dir/agents/openai.yaml"

  frontmatter_blocked=no
  # frontmatter は先頭の `---` 区切りの中だけを見る。本文で言及しても指定にならない。
  if sed -n '/^---$/,/^---$/p' "$skill_md" | grep -q '^disable-model-invocation:[[:space:]]*true[[:space:]]*$'; then
    frontmatter_blocked=yes
  fi

  codex_blocked=no
  if [[ -f "$openai_yaml" ]] &&
    grep -q '^[[:space:]]*allow_implicit_invocation:[[:space:]]*false[[:space:]]*$' "$openai_yaml"; then
    codex_blocked=yes
  fi

  if [[ "$frontmatter_blocked" != "$codex_blocked" ]]; then
    drift+=("$skill_name: SKILL.md=$frontmatter_blocked agents/openai.yaml=$codex_blocked")
  fi
done

if [[ ${#drift[@]} -gt 0 ]]; then
  echo "スキルの自動起動の指定が、Claude Code / Cursor 用と Codex 用で一致していません。"
  echo ""
  for line in "${drift[@]}"; do
    echo "  $line"
  done
  echo ""
  echo "手動起動専用にする場合は、両方を指定してください。"
  echo "  1) SKILL.md の frontmatter に disable-model-invocation: true を書く"
  echo "  2) agents/openai.yaml に policy.allow_implicit_invocation: false を書く"
  echo "自然言語から自動起動させる場合は、両方を削除してください。"
  exit 1
fi

echo "ok: スキルの自動起動の指定は Claude Code / Cursor と Codex で一致しています。"
