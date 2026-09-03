#!/usr/bin/env bash
# =============================================================================
# check-mermaid.sh — .md ファイルの Mermaid ブロックを検査する（lefthook 用）
# =============================================================================
# 用途   : lefthook の pre-commit から、ステージされた .md を引数に受けて検査する。
#          判定の実体は claude/hooks/lib/mermaid-check.sh にあり、
#          post-tool-use/mermaid-guard.sh と同じ関数を使う。
#
# WHY: Cursor CLI は PostToolUse の hook イベントを送らないため、hook だけに検査を
#      置くと CLI では働かない。コミット時に必ず通る lefthook へ同じ検査を置く。
#
# 使い方: bash scripts/check-mermaid.sh <file.md>...
# 終了コード: 0=エラーなし / 1=エラーあり
# =============================================================================

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../claude/hooks/lib/mermaid-check.sh
source "$SCRIPT_DIR/../claude/hooks/lib/mermaid-check.sh"

status=0
for file in "$@"; do
  if ! errors=$(mermaid_check_file "$file"); then
    printf '%s: Mermaid の記述に問題があります。\n%s\n' "$file" "$errors"
    status=1
  fi
done

exit "$status"
