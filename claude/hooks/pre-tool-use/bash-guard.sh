#!/usr/bin/env bash
# =============================================================================
# pre-tool-use/bash-guard.sh — Bash ツール実行前の安全確認
# =============================================================================
# フック  : PreToolUse（Bash）
# 役割   : description の記載必須項目をリスクレベル別に検証し、
#          通過・ユーザー確認（ask）・拒否（deny）を判定する。
#          リスクレベルは classify() が機械的に判定する。
#
# リスク階層による判定:
#   READ         : 状態を変えない（ls/cat/grep/git status/git diff/git log 等）
#                  → description のみ必須
#   WRITE        : ローカル状態を変える（mkdir/touch/mv/cp/sed -i/リダイレクト 等）
#                  → 目的: + 影響: 必須
#   INSTALL      : 依存追加（npm install/pnpm add/pip install/brew install 等）
#                  → 目的: + 影響: + 許可: + 拒否: 必須 + ユーザー確認（サプライチェーン攻撃のリスク）
#   NETWORK_WRITE: 外部状態を変える（git push/gh pr merge/gh api 書き込み 等）
#                  → 目的: + 影響: + 許可: + 拒否: 必須 + ユーザー確認
#   DESTRUCTIVE  : 取り返しがつかない（rm/git reset --hard/git push --force 等）
#                  → 目的: + 影響: + 許可: + 拒否: 必須 + ユーザー確認
#
# 個別ルール（階層判定の後に適用）:
#   - バックスラッシュ改行（継続行）を含むコマンドは deny
#   - 保護ブランチ上での git commit / git merge は deny（PR 経由を強制）
#   - WORK_RECORD_FILES がステージ済みで git commit しようとした場合は deny
#   - npm install（パッケージ名なし）と pip install -r は deny
#     WHY: semver範囲でバージョンが解決されるため、意図しないバージョンが入り、
#          挙動のズレ・脆弱性・サプライチェーン攻撃を含むバージョンを意図せず引き込む可能性がある
#     ※ npm install <pkg> / npm ci / pnpm install / yarn install / bun install は通過する
#
# 注: rm -rf / shred / xargs rm / find -delete 等は pre-tool-use/dangerous-guard.sh で拒否済み。
#     単一ファイルの rm は dangerous-guard.sh の対象外のため、このスクリプトで DESTRUCTIVE に分類する。
#
# 終了コード:
#   0 → 通過（READ / WRITE）または ask / deny JSON を出力して終了
#
# 入力 : stdin の JSON（tool_input.command / tool_input.description）
# 出力 : stdout の JSON（permissionDecision: "ask" または "deny"）
# =============================================================================

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../config.sh
source "$HOOKS_DIR/config.sh"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // ""')

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
    *"pnpm add"* |\
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

# --- READ は description のみで通過（過剰な要求をしない）---
if [ "$LEVEL" = "READ" ]; then
  exit 0
fi

# --- バックスラッシュ改行（継続行）→ deny ---
if printf '%s' "$COMMAND" | grep -qE '\\$'; then
  _deny "ERROR: バックスラッシュ改行（継続行）が含まれています。WHY: allow パターンの glob は改行文字にマッチしないため、同じような承認プロンプトが何度も発生しやすいです。FIX: コマンドからバックスラッシュを削除して1行に書き直してください。"
fi

# --- WRITE 以上は「目的:」「影響:」必須 ---
if ! echo "$DESCRIPTION" | grep -qE '目的[[:space:]]*[:：]'; then
  _deny "ERROR: [$LEVEL] description に目的が記載されていません。WHY: 状態を変える操作は「なぜ実行する必要があるのか」が必要です。FIX: 「目的:〜のため」を追加してください。"
fi
if ! echo "$DESCRIPTION" | grep -qE '影響[[:space:]]*[:：]'; then
  _deny "ERROR: [$LEVEL] description に影響範囲が記載されていません。WHY: 影響先が不明だとユーザーが Yes/No を判断できません。FIX: 「影響:origin/main の履歴上書き」「影響:node_modules 配下を全追加」のように対象を明記してください。"
fi

# --- INSTALL / NETWORK_WRITE / DESTRUCTIVE は「許可:」「拒否:」必須 ---
if [ "$LEVEL" = "INSTALL" ] || [ "$LEVEL" = "NETWORK_WRITE" ] || [ "$LEVEL" = "DESTRUCTIVE" ]; then
  if ! echo "$DESCRIPTION" | grep -qE '許可[[:space:]]*[:：]'; then
    _deny "ERROR: [$LEVEL] description に許可条件が記載されていません。WHY: ユーザーが Yes/No を判断するための基準が必要です。FIX: 「許可:〜の場合」を追加してください。"
  fi
  if ! echo "$DESCRIPTION" | grep -qE '拒否[[:space:]]*[:：]'; then
    _deny "ERROR: [$LEVEL] description に拒否条件が記載されていません。WHY: ユーザーが Yes/No を判断するための基準が必要です。FIX: 「拒否:〜の場合」を追加してください。"
  fi
fi

# --- 個別ルール: 保護ブランチ上での git commit → deny ---
if echo "$COMMAND_UNQUOTED" | grep -qE 'git[[:space:]]+commit'; then
  CURRENT_BRANCH=$(git -C "${CLAUDE_PROJECT_DIR:-$(pwd)}" branch --show-current 2>/dev/null || echo "")
  for pattern in "${PROTECTED_BRANCHES[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$CURRENT_BRANCH" == $pattern ]]; then
      _deny "ERROR: 保護ブランチ '$CURRENT_BRANCH' への直接コミットは禁止されています。WHY: レビューなしに変更が保護ブランチへ反映されるリスクがあります。FIX: フィーチャーブランチを作成してから Pull Request を作成してください。"
    fi
  done
fi

# --- 個別ルール: 保護ブランチ上での git merge → deny ---
if echo "$COMMAND_UNQUOTED" | grep -qE 'git[[:space:]]+merge'; then
  CURRENT_BRANCH=$(git -C "${CLAUDE_PROJECT_DIR:-$(pwd)}" branch --show-current 2>/dev/null || echo "")
  for pattern in "${PROTECTED_BRANCHES[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$CURRENT_BRANCH" == $pattern ]]; then
      _deny "ERROR: 保護ブランチ '$CURRENT_BRANCH' へのローカルマージは禁止されています。WHY: 直接マージによる意図しない変更混入を防ぎ、レビューを必須化するためです。FIX: GitHub で Pull Request を作成してください。"
    fi
  done
fi

# --- 個別ルール: git commit で WORK_RECORD_FILES がステージ済み → deny ---
if echo "$COMMAND_UNQUOTED" | grep -qE 'git[[:space:]]+commit'; then
  STAGED=$(git -C "${CLAUDE_PROJECT_DIR:-$(pwd)}" diff --cached --name-only 2>/dev/null || echo "")
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
    | sed 's/npm[[:space:]]\+i\(nstall\)\?[[:space:]]*//')
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
