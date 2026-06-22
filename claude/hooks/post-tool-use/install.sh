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
# 終了コード:
#   0 → 常に 0（PostToolUse はツール実行後のためブロック不可。
#        install 失敗は additionalContext で次ターンに通知する）
#
# 出力（PostToolUse の hookSpecificOutput.additionalContext 経由）:
#   成功: {"suppressOutput": true} を stdout、exit 0
#   失敗: {"hookSpecificOutput": {"hookEventName": "PostToolUse",
#         "additionalContext": "ERROR: ..."}} を stdout、exit 0
#
# 入力 : stdin の JSON（tool_input.file_path）
#        $PKG_MANAGER（session-start.sh が設定した環境変数、未設定時は自動検出）
# =============================================================================
INPUT=$(cat)
file=$(jq -r '.tool_input.file_path // ""' <<<"$INPUT")

[[ "$file" =~ package\.json$ ]] || exit 0

# $PKG_MANAGER → packageManager フィールド → lock file → npm の順で解決する
_resolve_pkg() {
  if [ -n "${PKG_MANAGER:-}" ]; then echo "$PKG_MANAGER"; return; fi
  if command -v node &>/dev/null && [ -f "package.json" ]; then
    local detected
    detected=$(node -e "try{const p=require('./package.json');console.log((p.packageManager||'').split('@')[0])}catch(e){}" 2>/dev/null)
    [ -n "$detected" ] && echo "$detected" && return
  fi
  if   [ -f "pnpm-lock.yaml" ];                 then echo "pnpm"; return
  elif [ -f "yarn.lock" ];                       then echo "yarn"; return
  elif [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then echo "bun";  return
  fi
  echo "npm"
}

cmd="$(_resolve_pkg) install"
output=$($cmd 2>&1)
exit_code=$?
if [ $exit_code -eq 0 ]; then
  echo '{"suppressOutput": true}'
  exit 0
fi
msg="ERROR: ${cmd} の実行に失敗しました。\nWHY: lock file との整合性がとれていないか、パッケージに問題がある可能性があります。\nFIX: 下記の出力を確認してパッケージの問題を解決してください。\n\n${output}"
printf '%s' "$msg" | python3 -c "import json,sys; print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': sys.stdin.read()}}))"
exit 0
