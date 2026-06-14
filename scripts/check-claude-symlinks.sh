#!/bin/bash
# settings.json が参照する ~/.claude/<path> が、setup.sh の SYMLINKS で
# 必ずリンクされることを検証する。
#
# 背景: claude/ 直下に設定ファイル（例: statusline.sh）を追加しても、setup.sh の
# SYMLINKS 配列への登録を忘れると ~/.claude/ にリンクが作られず、Claude Code が
# 参照先を見つけられない。登録漏れを人の注意力に頼らず CI / pre-commit で機械的に
# 検出するためのチェック。
#
# 不変条件:
#   settings.json 内の各 `~/.claude/<path>` 参照は、setup.sh の SYMLINKS の
#   リンク先（home 相対の `.claude/<path>`）に
#     - 完全一致する、または
#     - いずれかのディレクトリリンク先を接頭辞に持つ（例: .claude/hooks 配下）
#   いずれかで必ずカバーされていなければならない。

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS_JSON="$DOTFILES_DIR/claude/settings.json"
SETUP_SH="$DOTFILES_DIR/setup.sh"

if [[ ! -f "$SETTINGS_JSON" ]]; then
  echo "error: not found: $SETTINGS_JSON" >&2
  exit 1
fi
if [[ ! -f "$SETUP_SH" ]]; then
  echo "error: not found: $SETUP_SH" >&2
  exit 1
fi

# settings.json から ~/.claude/<path> 参照を抽出し、home 相対パス（.claude/<path>）へ正規化する。
# SC2088: `~/` は展開目的ではなく settings.json 内のリテラル文字列を grep するためのパターン。
# shellcheck disable=SC2088
references=$(grep -oE '~/\.claude/[A-Za-z0-9._/-]+' "$SETTINGS_JSON" | sed 's|^~/||' | sort -u || true)

# setup.sh の SYMLINKS から home 相対のリンク先（":" の右側、引用符まで）を抽出する。
# 例: "claude/statusline.sh:.claude/statusline.sh" -> .claude/statusline.sh
link_dsts=$(grep -oE '"claude/[^"]+:\.claude/[^"]+"' "$SETUP_SH" | sed -E 's/^"[^:]+://; s/"$//' | sort -u || true)

missing=0
while IFS= read -r ref; do
  [[ -z "$ref" ]] && continue
  covered=0
  while IFS= read -r dst; do
    [[ -z "$dst" ]] && continue
    # 完全一致、またはディレクトリリンク先の配下（dst/ が ref の接頭辞）
    if [[ "$ref" == "$dst" || "$ref" == "$dst/"* ]]; then
      covered=1
      break
    fi
  done <<< "$link_dsts"

  if [[ "$covered" -eq 0 ]]; then
    echo "NG: settings.json は ~/$ref を参照していますが、setup.sh の SYMLINKS に対応するリンク先がありません" >&2
    missing=1
  fi
done <<< "$references"

if [[ "$missing" -ne 0 ]]; then
  echo "" >&2
  echo "対処: setup.sh の SYMLINKS 配列に \"claude/<file>:.claude/<file>\" を追加してください。" >&2
  exit 1
fi

echo "OK: settings.json が参照する ~/.claude パスはすべて setup.sh の SYMLINKS でカバーされています。"
