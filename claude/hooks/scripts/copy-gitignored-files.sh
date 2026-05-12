#!/usr/bin/env bash
# =============================================================================
# scripts/copy-gitignored-files.sh — .gitignore ファイルを worktree へコピー
# =============================================================================
# フック  : worktree/create.sh から呼び出されるヘルパースクリプト
# 役割   : .gitignore を解析して、親 worktree に存在するファイルを
#          新しい worktree にコピーする（.env 等のセッション固有ファイルを引き継ぐ）。
#
# 使い方:
#   copy-gitignored-files.sh --list <REPO_PATH>           # コピー対象のファイル一覧を出力
#   copy-gitignored-files.sh <REPO_PATH> <WORKTREE_PATH>  # コピーを実行して一覧を出力
#
# 対象となるパターン:
#   - ワイルドカード（* ? [）を含まない
#   - 否定パターン（!）ではない
#   - <REPO_PATH> に実際に存在するファイル（ディレクトリは除く）
#
# コピーの方針:
#   - worktree ごとに独立して編集できるようコピーする（シンボリックリンクではない）
#   - ネストしたパスは mkdir -p で親ディレクトリを作成してからコピーする
#
# 終了コード:
#   0 → 成功（.gitignore がない場合も含む）
#   1 → 引数エラー
#
# 入力 : $1 = --list または REPO_PATH / $2 = REPO_PATH または WORKTREE_PATH
# 出力 : コピーしたファイル名を stdout に出力（1行1ファイル）
# =============================================================================

set -euo pipefail

# 引数のパース
if [ $# -eq 2 ] && [ "$1" = "--list" ]; then
  MODE="list"
  REPO_PATH="$2"
  WORKTREE_PATH=""
elif [ $# -eq 2 ]; then
  MODE="copy"
  REPO_PATH="$1"
  WORKTREE_PATH="$2"
else
  echo "Usage:" >&2
  echo "  $0 --list <REPO_PATH>           # コピー対象のファイル一覧を出力" >&2
  echo "  $0 <REPO_PATH> <WORKTREE_PATH>  # コピーを実行して一覧を出力" >&2
  exit 1
fi

GITIGNORE="$REPO_PATH/.gitignore"

if [ ! -f "$GITIGNORE" ]; then
  # .gitignore がなければ何もしない（エラーではない）
  exit 0
fi

# .gitignore を1行ずつ処理してコピー対象ファイルを収集する
while IFS= read -r raw_line || [ -n "$raw_line" ]; do
  # 前後の空白を除去
  line="${raw_line#"${raw_line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"

  # 空行・コメント行をスキップ
  [ -z "$line" ] && continue
  [[ "$line" == \#* ]] && continue

  # 否定パターンをスキップ
  [[ "$line" == \!* ]] && continue

  # ワイルドカードを含むパターンをスキップ（* ? [）
  [[ "$line" == *[\*\?\[]* ]] && continue

  # 先頭・末尾のスラッシュを除去
  line="${line#/}"
  line="${line%/}"

  # <REPO_PATH> に実際に存在するファイルのみ対象
  [ -f "$REPO_PATH/$line" ] || continue

  if [ "$MODE" = "list" ]; then
    echo "$line"
  else
    # コピー先のディレクトリを作成してコピー
    dest_dir=$(dirname "$WORKTREE_PATH/$line")
    mkdir -p "$dest_dir"
    cp "$REPO_PATH/$line" "$WORKTREE_PATH/$line"
    echo "$line"
  fi
done < "$GITIGNORE"
