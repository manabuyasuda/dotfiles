#!/usr/bin/env bash
# =============================================================================
# pre-tool-use/branch-guard.sh — 保護ブランチへの直接ファイル編集をブロック
# =============================================================================
# フック  : PreToolUse（Edit / MultiEdit / Write）
# 役割   : 保護ブランチ上でファイルを直接編集しようとしたとき、exit 2 でハードブロックする。
#          フィーチャーブランチを作成してから作業するよう強制する。
#          git merge によるローカルマージの防止は pre-tool-use/bash-guard.sh が担当する。
#
# 保護ブランチ定義: config.sh（hooks/ 直下）で一元管理。glob パターン可。
#
# 終了コード:
#   0      → 通過（保護ブランチ以外、または detached HEAD）
#   2      → ハードブロック（保護ブランチ上での編集）
#
# 入力 : stdin の JSON（tool_input.file_path または tool_input.path）
# =============================================================================

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../config.sh
source "$HOOKS_DIR/config.sh"

# jq --arg でメッセージをエスケープ（ブランチ名に ' などが含まれても JSON が壊れない）
_deny() {
  jq -n --arg msg "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$msg}}'
  exit 2
}

input="$(cat)"
file_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')"

# file_path が取れない場合は判定対象がないため通過させる。
if [ -z "$file_path" ]; then
  exit 0
fi

# 新規ファイルで親ディレクトリが未作成のケースに備え、存在する祖先ディレクトリまで遡る。
search_dir="$(dirname "$file_path")"
while [ ! -d "$search_dir" ] && [ "$search_dir" != "/" ] && [ "$search_dir" != "." ]; do
  search_dir="$(dirname "$search_dir")"
done

# file_path が属するリポジトリを特定する。git 管理外なら通過させる。
repo_root="$(git -C "$search_dir" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$repo_root" ]; then
  exit 0
fi

current_branch="$(git -C "$repo_root" branch --show-current 2>/dev/null)"

# detached HEAD はブランチ名が取れないためブロックできない。警告のみ出して通過させる。
if [ -z "$current_branch" ]; then
  echo '{"feedback": "WARNING: detached HEAD 状態です。ブランチを作成してから作業してください。"}' >&2
  exit 0
fi

# config.sh の PROTECTED_BRANCHES を glob パターンとして照合する。
# SC2053: [[ == ]] の右辺をクォートしないことで glob 展開を有効にする（意図的）。
for pattern in "${PROTECTED_BRANCHES[@]}"; do
  # shellcheck disable=SC2053
  if [[ "$current_branch" == $pattern ]]; then
    _deny "ERROR: ブランチ '${current_branch}' は保護ブランチです（リポジトリ: ${repo_root}）。直接編集できません。WHY: 保護ブランチへの直接コミットを防ぎ、レビューを必須化するためです。FIX: git pull で最新にしてから git checkout -b feature/your-branch-name でフィーチャーブランチを作成してから作業してください。"
  fi
done

exit 0
