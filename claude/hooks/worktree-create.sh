#!/usr/bin/env bash
#
# worktree-create.sh - WorktreeCreate hook
#
# `claude --worktree <branch>` 実行時に自動で呼ばれる。
# wtp でworktreeを作成し、gitignored ファイルのコピー、
# クリップボードへの初期化コマンド生成、SourceTree での起動を行う。
#
# 入力: {"name": "<branch-name>"} (stdin経由)
# 出力: worktreeのパス (stdout) → Claude Code がこのパスに切り替える

set -euo pipefail

INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name // ""')

if [ -z "$NAME" ]; then
  echo "Error: name is empty" >&2
  exit 1
fi

REPO_PATH=$(git rev-parse --show-toplevel)
DEFAULT_BRANCH=$(git -C "$REPO_PATH" symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')

# デフォルトブランチを最新化
git -C "$REPO_PATH" checkout "$DEFAULT_BRANCH" >&2
git -C "$REPO_PATH" pull origin "$DEFAULT_BRANCH" >&2

# wtp で worktree を作成し、Location からパスを取得
OUT=$(cd "$REPO_PATH" && wtp add -b "$NAME" 2>&1)
echo "$OUT" >&2
WORKTREE_PATH=$(echo "$OUT" | grep "Location:" | sed "s/.*Location: //")

if [ -z "$WORKTREE_PATH" ]; then
  echo "Error: wtp の出力から worktree パスを取得できませんでした" >&2
  exit 1
fi

# gitignored ファイルをコピー（.envrc など）し、コピーしたファイル一覧を取得
COPY_FILES=$(bash "$HOME/.claude/hooks/scripts/copy-gitignored-files.sh" \
  "$REPO_PATH" "$WORKTREE_PATH")

# 初期化コマンドを生成してクリップボードにコピー
CLIPBOARD_CMD=""

# .envrc がコピーされた場合は direnv allow を先頭に追加
if echo "$COPY_FILES" | grep -q "\.envrc"; then
  CLIPBOARD_CMD="direnv allow; "
fi

# パッケージマネージャーをロックファイルで自動検出してインストールコマンドを追加
if [ -f "$WORKTREE_PATH/yarn.lock" ]; then
  CLIPBOARD_CMD="${CLIPBOARD_CMD}yarn install; "
elif [ -f "$WORKTREE_PATH/pnpm-lock.yaml" ]; then
  CLIPBOARD_CMD="${CLIPBOARD_CMD}pnpm install; "
elif [ -f "$WORKTREE_PATH/package-lock.json" ]; then
  CLIPBOARD_CMD="${CLIPBOARD_CMD}npm install; "
fi

CLIPBOARD_CMD="${CLIPBOARD_CMD}claude"
echo "$CLIPBOARD_CMD" | pbcopy >&2

# SourceTree で開く
open -a SourceTree "$WORKTREE_PATH" >&2 || echo "SourceTree が見つかりません、スキップします" >&2

# worktree のパスを出力（Claude Code がこのパスに切り替える）
echo "$WORKTREE_PATH"
