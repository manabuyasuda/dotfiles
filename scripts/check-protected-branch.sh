#!/usr/bin/env bash
# =============================================================================
# check-protected-branch.sh — 保護ブランチ上でのコミットを止める（lefthook 用）
# =============================================================================
# 用途   : lefthook の pre-commit から呼ばれ、現在のブランチが保護ブランチなら
#          非ゼロ終了してコミットを止める。
#
# 保護ブランチ定義: claude/hooks/config.sh の PROTECTED_BRANCHES を唯一の情報源と
#          して参照する。ブランチ名の文字列をこのファイルや lefthook.yml へ
#          重複して書かない。
#
# WHY: 保護ブランチへの直接編集は pre-tool-use/branch-guard.sh が止めているが、
#      Cursor CLI は PreToolUse の hook イベントを送らないため CLI では働かない。
#      さらに hook はエージェント経由の編集しか見ないので、人手の編集は素通りする。
#      コミットは経路によらず必ず通るため、ここで止めれば構造的に強制できる。
#
# Why not: 環境変数などの回避手段は用意しない。回避手段を残すとエージェントが
#          それを使い、強制にならない。緊急時も git switch -c でブランチを切れば
#          作業を続けられる。
#
# 終了コード: 0=保護ブランチではない（detached HEAD を含む） / 1=保護ブランチ
# =============================================================================

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../claude/hooks/config.sh
source "$SCRIPT_DIR/../claude/hooks/config.sh"

current_branch=$(git branch --show-current 2>/dev/null)

# detached HEAD はブランチ名が取れず照合できない。通常のコミット操作ではないため、
# 警告だけ出して通す。
if [ -z "$current_branch" ]; then
  echo "WARNING: detached HEAD です。ブランチを作成してから作業してください。"
  exit 0
fi

for pattern in "${PROTECTED_BRANCHES[@]}"; do
  # shellcheck disable=SC2053
  # [[ == ]] の右辺をクォートしないことで glob 展開を有効にする（release/* 等）。
  if [[ "$current_branch" == $pattern ]]; then
    echo "ブランチ '${current_branch}' は保護ブランチです。直接コミットできません。"
    echo "git switch -c feature/your-branch-name でブランチを作成してからコミットしてください。"
    exit 1
  fi
done

exit 0
