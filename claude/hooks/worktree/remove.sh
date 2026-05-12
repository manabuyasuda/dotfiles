#!/usr/bin/env bash
# =============================================================================
# worktree/remove.sh — worktree の削除
# =============================================================================
# フック  : WorktreeRemove（`claude --worktree` セッション終了時に "remove" を選択した場合）
# 役割   : wtp で worktree を削除し、ブランチクリーンアップコマンド（gh poi）を
#          クリップボードにコピーする。ブランチ自体の安全な削除は gh poi に委任する。
#
# 入力 : stdin の JSON（worktree_path: worktree のパス）
# =============================================================================

set -euo pipefail

INPUT=$(cat)
WORKTREE_PATH=$(echo "$INPUT" | jq -r '.worktree_path // ""')

if [ -z "$WORKTREE_PATH" ]; then
  echo "Error: worktree_path is empty" >&2
  exit 1
fi

# worktree のブランチ名を取得
BRANCH=$(git -C "$WORKTREE_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# メインリポジトリのパスを取得（worktree の .git は共通 .git を指す）
GIT_COMMON_DIR=$(git -C "$WORKTREE_PATH" rev-parse --git-common-dir)
MAIN_REPO=$(dirname "$GIT_COMMON_DIR")

# wtp で worktree を削除（ブランチは残す。gh poi で安全に削除する）
if [ -n "$BRANCH" ]; then
  cd "$MAIN_REPO" && wtp remove "$BRANCH" >&2
else
  git worktree remove "$WORKTREE_PATH" >&2
fi

# ブランチクリーンアップコマンドをクリップボードにコピー
echo 'gh poi --state closed' | pbcopy >&2
