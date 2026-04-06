#!/usr/bin/env bash
# =============================================================================
# post-tool-use/install.sh — package.json 変更後の依存自動インストール
# =============================================================================
# フック  : PostToolUse（Edit / MultiEdit / Write）
# 役割   : エージェントが package.json を直接編集したとき、
#          lock file との整合性がずれないよう自動でインストールを実行する。
#          エージェントが CLI を使わず dependencies を直接書き換えた場合に
#          install が漏れることを防ぐための保険。
#
# 対象ファイル: package.json のみ（それ以外は即 exit 0）
#
# パッケージマネージャーの解決順:
#   1. $PKG_MANAGER（session-start.sh が $CLAUDE_ENV_FILE に保存した値）
#   2. package.json の packageManager フィールド
#   3. lock file の存在（pnpm-lock.yaml / yarn.lock / bun.lock）
#   4. npm（フォールバック）
#
# 注意:
#   scripts のみ変更した場合も install が走るが、
#   lock file が整合済みであれば即終了するため実害はない。
#   このスクリプトは Bash 経由で install を実行するため、
#   pre-tool-use/file-protect.sh の lock file ガードとは干渉しない。
#
# 入力 : $CLAUDE_TOOL_INPUT_FILE_PATH
#        $PKG_MANAGER（session-start.sh が設定した環境変数、未設定時は自動検出）
# =============================================================================
[[ "$CLAUDE_TOOL_INPUT_FILE_PATH" =~ package\.json$ ]] || exit 0

pkg="${PKG_MANAGER:-}"
if [ -z "$pkg" ]; then
  if command -v node &>/dev/null && [ -f "package.json" ]; then
    pkg=$(node -e "try{const p=require('./package.json');console.log((p.packageManager||'').split('@')[0])}catch(e){}" 2>/dev/null)
  fi
fi
if [ -z "$pkg" ]; then
  if   [ -f "pnpm-lock.yaml" ];                   then pkg="pnpm"
  elif [ -f "yarn.lock" ];                         then pkg="yarn"
  elif [ -f "bun.lockb" ] || [ -f "bun.lock" ];   then pkg="bun"
  else pkg="npm"
  fi
fi

cmd="$pkg install"
echo "{\"feedback\": \"Running $cmd to sync lock file...\"}" >&2
$cmd >/dev/null 2>&1 && \
  echo "{\"feedback\": \"$cmd completed.\", \"suppressOutput\": true}" || {
  echo "{\"feedback\": \"$cmd failed.\"}" >&2
  exit 1
}
