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
#   1. package.json の packageManager フィールド
#   2. lock file の存在（pnpm-lock.yaml / yarn.lock / bun.lock）
#   3. npm（フォールバック）
#
# ツール実在ゲート:
#   解決したパッケージマネージャーが PATH 上に無ければ無言で通過する（exit 0）。
#   Why not: 実体が無いまま実行するとコマンド不在のエラーを install 失敗として
#            additionalContext へ注入し、原因を指さないメッセージが編集のたびに
#            出るため。実体の有無で決めれば構造的に起こらない。
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
# =============================================================================
INPUT=$(cat)

# Cursor 互換実行（cursor_version あり）は cursor/hooks.json のアダプタ側で判定済みのため通過する
# shellcheck source=../lib/cursor-compat.sh
source "$(dirname "$0")/../lib/cursor-compat.sh"
exit_if_cursor_payload "$INPUT"
file=$(jq -r '.tool_input.file_path // ""' <<<"$INPUT")

[[ "$file" =~ package\.json$ ]] || exit 0

# packageManager フィールド → lock file → npm の順で解決する
_resolve_pkg() {
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

pkg="$(_resolve_pkg)"

# 解決したパッケージマネージャーが環境に無ければ無言で通過する
if ! command -v "$pkg" &>/dev/null; then
  echo '{"suppressOutput": true}'
  exit 0
fi

cmd="$pkg install"
output=$($cmd 2>&1)
exit_code=$?
if [ $exit_code -eq 0 ]; then
  echo '{"suppressOutput": true}'
  exit 0
fi
msg="ERROR: ${cmd} の実行に失敗しました。\nWHY: lock file との整合性がとれていないか、パッケージに問題がある可能性があります。\nFIX: 下記の出力を確認してパッケージの問題を解決してください。\n\n${output}"
printf '%s' "$msg" | python3 -c "import json,sys; print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': sys.stdin.read()}}))"
exit 0
