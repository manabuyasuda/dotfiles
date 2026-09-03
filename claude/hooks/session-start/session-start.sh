#!/usr/bin/env bash
# =============================================================================
# session-start.sh — セッション開始時の初期化確認
# =============================================================================
# フック  : SessionStart（セッション開始時に1回だけ実行）
# 役割   : 3つ。
#          1. プロジェクトが未初期化（package.json があるのに node_modules がない）の
#             場合だけ、その事実と git worktree かどうかをエージェントへ伝える。
#             対応（依存インストール・gitignored ファイルの用意など）は受け取った
#             エージェント側が判断する。
#          2. plan/ にある直近の計画ファイルを一覧してエージェントへ伝える。
#             引き継ぎ作業のとき、既存の計画の存在に気づかないまま着手するのを防ぐ。
#          3. plan-guard.sh の基準時刻ファイル ${TMPDIR:-/tmp}/session-start-<session_id>
#             を作る。plan-guard はこれより新しい plan/ のファイルがあるかで
#             「このセッションで計画を書いたか」を判定する。
#
# 出力: stdout → Claude のコンテキストに注入される
#
# かつてこの hook が担っていた処理は、以下の理由で削除した（実測で中央値4.5秒・
# 最大約10秒かかり、timeout 10秒に到達していたため）:
#   - 開発ツール検出と $CLAUDE_ENV_FILE への書き出し
#     → 参照していた format.sh / install.sh は自力検出フォールバックを
#       持つため、検出ロジックを読み手側へ一本化した
#   - git 状態（ブランチ・直近コミット・未コミット変更）の表示
#     → Claude Code 本体が gitStatus を自動注入するため冗長
#   - gh 未認証・Node 不在の警告
#     → gh 未認証は実行時に check-gh-account.sh が検出する
#
# 所要時間: 2026-09-03 実測で 0.06〜0.07 秒（plan/ に 18 ファイルある状態）。timeout 10 秒
#          に対して十分小さい。かつてこの hook が timeout に到達した経緯は上記の通り。
#
# 終了コード: 常に 0（ブロックしない。情報提供のみ）
# =============================================================================

INPUT=$(cat)

# 基準時刻ファイルを作る。plan-guard.sh はこのファイルの更新時刻を「セッション開始」と
# みなし、plan/ にこれより新しいファイルがあるかを見る。session_id が取れないときは
# 作らない（plan-guard 側は基準時刻ファイルが無ければフェイルオープンする）。
if command -v jq &>/dev/null; then
  SESSION_ID=$(jq -r '.session_id // ""' <<<"$INPUT" 2>/dev/null)
  [ -n "$SESSION_ID" ] && : > "${TMPDIR:-/tmp}/session-start-${SESSION_ID}" 2>/dev/null
fi

# plan/ の直近の計画を一覧する。上限5件にしているのは、引き継ぎで必要になるのは直近の
# 作業に限られる一方、plan/ はコミット対象外で古いファイルが残り続けるため。全件出すと
# セッションのたびにトークンを消費する。
if [ -d "plan" ]; then
  PLAN_LIST=$(
    find plan -maxdepth 1 -type f -name '*.md' ! -empty -print0 2>/dev/null |
      xargs -0 ls -t 2>/dev/null | head -n 5 |
      while IFS= read -r f; do
        printf -- '- %s: %s\n' "$f" "$(head -n 1 "$f" | sed 's/^#* *//')"
      done
  )
  if [ -n "$PLAN_LIST" ]; then
    echo "=== plan/ にある直近の計画 ==="
    echo "$PLAN_LIST"
    echo "この作業に対応する計画があれば読んでから着手してください。無ければ plan-writer で作成してください。"
  fi
fi

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
