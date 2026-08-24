#!/usr/bin/env bash
# =============================================================================
# pre-tool-use/bash-guard.sh — Bash ツール実行前の安全確認
# =============================================================================
# フック  : PreToolUse（Bash）
# 役割   : コマンドのリスクレベルを classify() で機械判定し、
#          通過・ユーザー確認（ask）・拒否（deny）を判定する。
#          description は判定に使わない。Cursor CLI の preToolUse ペイロードには
#          description が存在せず、記載必須にするとエージェントに修正手段のない
#          恒久 deny になるため（Why not: description プロトコルは除去済み）。
#
# リスク階層による判定:
#   READ         : 状態を変えない（ls/cat/grep/git status/git diff/git log 等）→ 通過
#   WRITE        : ローカル状態を変える（mkdir/touch/mv/cp/sed -i/リダイレクト 等）→ 通過
#   INSTALL      : 依存追加（npm install/pnpm add/pip install/brew install 等）
#                  → ユーザー確認（サプライチェーン攻撃のリスク）
#   NETWORK_WRITE: 外部状態を変える（git push/gh pr merge/gh api 書き込み 等）→ ユーザー確認
#   DESTRUCTIVE  : 取り返しがつかない（rm/git reset --hard/git push --force 等）→ ユーザー確認
#
# 個別ルール（階層判定の後に適用）:
#   - バックスラッシュ改行（継続行）を含むコマンドは deny
#   - 保護ブランチ上での git commit / git merge は deny（PR 経由を強制）
#   - WORK_RECORD_FILES がステージ済みで git commit しようとした場合は deny
#   - npm install（パッケージ名なし）と pip install -r は deny
#     WHY: semver範囲でバージョンが解決されるため、意図しないバージョンが入り、
#          挙動のズレ・脆弱性・サプライチェーン攻撃を含むバージョンを意図せず引き込む可能性がある
#     ※ npm install <pkg> / npm ci / pnpm install --frozen-lockfile / yarn install --immutable は通過する
#       pnpm install（--frozen-lockfile なし）・yarn install（--immutable なし）は INSTALL としてユーザー確認
#
# 注: rm -rf / shred / xargs rm / find -delete 等は pre-tool-use/dangerous-guard.sh で拒否済み。
#     単一ファイルの rm は dangerous-guard.sh の対象外のため、このスクリプトで DESTRUCTIVE に分類する。
#
# 終了コード:
#   0 → 通過（READ / WRITE）または ask / deny JSON を出力して終了
#
# 入力 : stdin の JSON（tool_input.command）
# 出力 : stdout の JSON（permissionDecision: "ask" または "deny"）
# =============================================================================

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../config.sh
source "$HOOKS_DIR/config.sh"

INPUT=$(cat)

# Cursor 互換実行（cursor_version あり）は cursor/hooks.json のアダプタ側で判定済みのため通過する
# shellcheck source=../lib/cursor-compat.sh
source "$(dirname "$0")/../lib/cursor-compat.sh"
exit_if_cursor_payload "$INPUT"

# command / cwd を1回の jq でまとめて取得する（同一 stdin を2回 parse しない）。
# command は改行を含み得るため、read（改行で切れる）ではなく NUL 区切り＋mapfile で
# 分割する。各フィールドを NUL 終端して連結し（join + 末尾 NUL）、末尾要素のズレを防ぐ。
# コミット先のブランチは「いま作業しているディレクトリ（worktree）」で判定する。
# CLAUDE_PROJECT_DIR は worktree 切り替えに追従せず起動時のプロジェクトルートを指したままなので、
# worktree 上での git commit / git merge を誤って保護ブランチ扱いしてしまう。
# Claude Code が hook 入力で渡す .cwd（worktree に追従する）を使い、空のときだけ pwd にフォールバックする。
mapfile -d '' -t _fields < <(
  jq -j '[.tool_input.command // "", .cwd // ""]
         | join("\u0000") + "\u0000"' <<<"$INPUT"
)
COMMAND="${_fields[0]:-}"
CWD="${_fields[1]:-}"

# 引用符内の文字列を除去してパターンマッチングの誤検知を防ぐ
# （例: grep "git push" が git push コマンドとして誤検知されることを防ぐ）
COMMAND_UNQUOTED=$(echo "$COMMAND" | sed 's/"[^"]*"//g; s/'"'"'[^'"'"']*'"'"'//g')

_deny() {
  jq -n --arg msg "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$msg}}'
  exit 0
}

_ask() {
  jq -n --arg msg "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":$msg}}'
  exit 0
}

# --- リスク階層を機械判定 ---
classify() {
  local c="$1"
  case "$c" in

    # frozen lockfile install: lockfile に固定されたバージョンのみインストール。新バージョンを解決しない
    *"npm ci"* |\
    *"pnpm install --frozen-lockfile"* |\
    *"yarn install --immutable"*)
      echo "READ"; return;;

    # DESTRUCTIVE: 取り返しがつかない操作
    # ※ git push --force / git reset --hard は NETWORK_WRITE より前に評価する必要がある
    *"git reset --hard"* |\
    *"git push --force"* |\
    *"git push -f "* |\
    *"git push --force-with-lease"* |\
    *"git commit"*"--amend"* |\
    *"rm "* |\
    *"unlink "* |\
    *"truncate "*)
      echo "DESTRUCTIVE"; return;;

    # NETWORK_WRITE: 外部リポジトリ・GitHub の状態を変える操作
    # gh api は書き込みメソッド（-X / --method）またはフィールド指定（--field / -f）で判定
    *"git commit"* |\
    *"git push"* |\
    *"npm publish"* |\
    *"gh pr merge"* |\
    *"gh issue close"* |\
    *"gh api"*"-X POST"* |\
    *"gh api"*"-X PUT"* |\
    *"gh api"*"-X PATCH"* |\
    *"gh api"*"-X DELETE"* |\
    *"gh api"*"--method POST"* |\
    *"gh api"*"--method PUT"* |\
    *"gh api"*"--method PATCH"* |\
    *"gh api"*"--method DELETE"* |\
    *"gh api"*"--field "* |\
    *"gh api"*" -f "*)
      echo "NETWORK_WRITE"; return;;

    # INSTALL: 依存パッケージの追加（lock file・node_modules を変更する。サプライチェーン攻撃のリスク）
    *"npm install"* |\
    *"npm i "* |\
    *"yarn add"* |\
    *"yarn install"* |\
    *"pnpm add"* |\
    *"pnpm install"* |\
    *"pip install"* |\
    *"brew install"*)
      echo "INSTALL"; return;;

    # WRITE: ローカルファイルシステムを変更する操作
    *" > "* |\
    *" >> "* |\
    *"sed -i"* |\
    *"mkdir "* |\
    *"touch "* |\
    *"mv "* |\
    *"cp "*)
      echo "WRITE"; return;;

    # READ: 状態を変えない参照系操作
    *)
      echo "READ"; return;;

  esac
}

LEVEL=$(classify "$COMMAND_UNQUOTED")

# --- READ は通過（過剰な要求をしない）---
if [ "$LEVEL" = "READ" ]; then
  exit 0
fi

# --- バックスラッシュ改行（継続行）→ deny ---
if printf '%s' "$COMMAND" | grep -qE '\\$'; then
  _deny "ERROR: バックスラッシュ改行（継続行）が含まれています。WHY: allow パターンの glob は改行文字にマッチしないため、同じような承認プロンプトが何度も発生しやすいです。FIX: コマンドからバックスラッシュを削除して1行に書き直してください。"
fi

# --- 個別ルール: 保護ブランチ上での git commit → deny ---
if echo "$COMMAND_UNQUOTED" | grep -qE 'git[[:space:]]+commit'; then
  CURRENT_BRANCH=$(git -C "${CWD:-$(pwd)}" branch --show-current 2>/dev/null || echo "")
  for pattern in "${PROTECTED_BRANCHES[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$CURRENT_BRANCH" == $pattern ]]; then
      _deny "ERROR: 保護ブランチ '$CURRENT_BRANCH' への直接コミットは禁止されています。WHY: レビューなしに変更が保護ブランチへ反映されるリスクがあります。FIX: フィーチャーブランチを作成してから Pull Request を作成してください。"
    fi
  done
fi

# --- 個別ルール: 保護ブランチ上での git merge → deny ---
if echo "$COMMAND_UNQUOTED" | grep -qE 'git[[:space:]]+merge'; then
  CURRENT_BRANCH=$(git -C "${CWD:-$(pwd)}" branch --show-current 2>/dev/null || echo "")
  for pattern in "${PROTECTED_BRANCHES[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$CURRENT_BRANCH" == $pattern ]]; then
      _deny "ERROR: 保護ブランチ '$CURRENT_BRANCH' へのローカルマージは禁止されています。WHY: 直接マージによる意図しない変更混入を防ぎ、レビューを必須化するためです。FIX: GitHub で Pull Request を作成してください。"
    fi
  done
fi

# --- 個別ルール: git commit で WORK_RECORD_FILES がステージ済み → deny ---
if echo "$COMMAND_UNQUOTED" | grep -qE 'git[[:space:]]+commit'; then
  STAGED=$(git -C "${CWD:-$(pwd)}" diff --cached --name-only 2>/dev/null || echo "")
  file_pattern=$(IFS='|'; echo "${WORK_RECORD_FILES[*]}" | sed 's/\./\\./g')
  dir_pattern=$(IFS='|'; echo "${WORK_RECORD_DIRS[*]}")
  matched=$(echo "$STAGED" | grep -E "^($file_pattern)$|^($dir_pattern)/")
  if [ -n "$matched" ]; then
    restore_args=$(echo "$matched" | tr '\n' ' ')
    _deny "ERROR: 作業記録ファイルがステージされています。WHY: これらはセッション中の作業記録であり、コミット履歴に含めてはいけません。FIX: git restore --staged ${restore_args}を実行してから再度コミットしてください。"
  fi
fi

# --- 個別ルール: npm install（パッケージ名なし）/ pip install -r → deny ---
# pip/pip3 install -r / uv pip install -r: requirementsファイルからの一括インストール
if echo "$COMMAND_UNQUOTED" | grep -qE '(^|[|;&][[:space:]]*)pip3?[[:space:]]+install[[:space:]].*(-r|--requirement)[[:space:]]'; then
  _deny "ERROR: pip install -r をパッケージ名なしで実行しようとしています。WHY: semver範囲でバージョンが解決されるため、挙動のズレ・脆弱性・サプライチェーン攻撃を含むバージョンを意図せず引き込む可能性があります。FIX: 特定のパッケージを追加したい場合はpip install <package-name>を使ってください。"
fi
if echo "$COMMAND_UNQUOTED" | grep -qE '(^|[|;&][[:space:]]*)uv[[:space:]]+pip[[:space:]]+install[[:space:]].*(-r|--requirement)[[:space:]]'; then
  _deny "ERROR: uv pip install -r をパッケージ名なしで実行しようとしています。WHY: semver範囲でバージョンが解決されるため、挙動のズレ・脆弱性・サプライチェーン攻撃を含むバージョンを意図せず引き込む可能性があります。FIX: 特定のパッケージを追加したい場合はuv pip install <package-name>を使ってください。"
fi
# npm install / npm i: フラグ以外のトークン（パッケージ名）がなければパッケージ追加・削除なし
if echo "$COMMAND_UNQUOTED" | grep -qE '(^|[|;&][[:space:]]*)npm[[:space:]]+(install|i)([[:space:]]|$)'; then
  rest=$(echo "$COMMAND_UNQUOTED" \
    | grep -oE 'npm[[:space:]]+(install|i)[[:space:]]*[^|;&]*' \
    | head -1 \
    | sed -E 's/^npm[[:space:]]+(i|install)[[:space:]]*//')
  pkg_count=$(echo "$rest" | tr ' ' '\n' | grep -v '^$' | grep -cvE '^-' || true)
  if [ "$pkg_count" -eq 0 ]; then
    _deny "ERROR: npm install をパッケージ名なしで実行しようとしています。WHY: semver範囲でバージョンが解決されるため、挙動のズレ・脆弱性・サプライチェーン攻撃を含むバージョンを意図せず引き込む可能性があります。FIX: 特定のパッケージを追加したい場合はnpm install <package-name>を、lockfileを再現したい場合はnpm ciを使ってください。"
  fi
fi

# --- INSTALL / NETWORK_WRITE / DESTRUCTIVE → ユーザー確認 ---
if [ "$LEVEL" = "INSTALL" ] || [ "$LEVEL" = "NETWORK_WRITE" ] || [ "$LEVEL" = "DESTRUCTIVE" ]; then
  _ask "[$LEVEL] コマンド: $COMMAND"
fi

# WRITE は通過
exit 0
