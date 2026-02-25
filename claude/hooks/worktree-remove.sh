#!/usr/bin/env bash
#
# worktree-remove.sh - WorktreeRemove hook
#
# `claude --worktree` セッション終了時に "remove" を選択すると自動で呼ばれる。
# wtp で worktree を削除し、ブランチクリーンアップコマンドをクリップボードにコピーする。
# ブランチの安全な削除は gh poi に委任する。
#
# 入力: {"worktree_path": "<path>"} (stdin経由)

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
