#!/usr/bin/env bash
# =============================================================================
# session-start.sh — セッション開始時の初期化確認
# =============================================================================
# フック  : SessionStart（セッション開始時に1回だけ実行）
# 役割   : プロジェクトが未初期化（package.json があるのに node_modules がない）の
#          場合だけ、その事実と git worktree かどうかをエージェントへ伝える。
#          対応（依存インストール・gitignored ファイルの用意など）は受け取った
#          エージェント側が判断する。
#
# 出力: stdout → Claude のコンテキストに注入される（未初期化のときだけ出力する）
#
# かつてこの hook が担っていた処理は、以下の理由で削除した（実測で中央値4.5秒・
# 最大約10秒かかり、timeout 10秒に到達していたため）:
#   - 開発ツール検出と $CLAUDE_ENV_FILE への書き出し
#     → 参照していた format.sh / install.sh / test.sh は自力検出フォールバックを
#       持つため、検出ロジックを読み手側へ一本化した
#   - git 状態（ブランチ・直近コミット・未コミット変更）の表示
#     → Claude Code 本体が gitStatus を自動注入するため冗長
#   - gh 未認証・Node 不在の警告
#     → gh 未認証は実行時に check-gh-account.sh が検出する
#
# 終了コード: 常に 0（ブロックしない。情報提供のみ）
# =============================================================================

# 初期化の確認: package.json があるのに node_modules がなければ未初期化と判定する
if [ -f "package.json" ] && [ ! -d "node_modules" ]; then
  GIT_DIR=$(git rev-parse --git-dir 2>/dev/null || echo "")
  if echo "$GIT_DIR" | grep -q "/worktrees/"; then
    WORKTREE_NOTE="このディレクトリは git worktree です。"
  else
    WORKTREE_NOTE=""
  fi
  echo "=== プロジェクトが未初期化です ==="
  echo "package.json がありますが node_modules がありません。${WORKTREE_NOTE}"
  echo "依存パッケージのインストールや gitignored ファイル（.envrc 等）の用意が必要かどうかを判断して対応してください。"
fi

exit 0
