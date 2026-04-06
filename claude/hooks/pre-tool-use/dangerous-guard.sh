#!/usr/bin/env bash
# =============================================================================
# pre-tool-use/dangerous-guard.sh — 不可逆な破壊的コマンドを deny でブロック
# =============================================================================
# フック  : PreToolUse（Bash）
# 役割   : 実行すると取り消せない操作を Claude Code レベルで阻止する。
#          git 操作（push --force / reset --hard）は reflog で復元可能なため
#          このファイルでは扱わない（pre-tool-use/bash-guard.sh で ask 処理する）。
#
# 並列実行の注意:
#   pre-tool-use/bash-guard.sh と同じ PreToolUse(Bash) イベントで並列実行される。
#   `rm` 単体は pre-tool-use/bash-guard.sh が ask するが、
#   `rm -rf` はこのスクリプトが deny するため deny が優先される。
#
# deny メッセージの設計方針:
#   - 何が起きるか（結果）を具体的に説明する
#   - ユーザーが意図した操作なら手動実行できるようコマンドを明示する
#
# 入力 : stdin の JSON（tool_input.command）
# 出力 : stdout の JSON（permissionDecision: "deny"）
# =============================================================================

INPUT=$(cat)
cmd=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# jq の --arg オプションで $cmd を JSON 安全に埋め込む（特殊文字・改行をエスケープ）。
_deny() {
  jq -n --arg msg "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$msg}}'
  exit 0
}

# rm -rf / rm -r: ファイルを再帰的に削除。git 管理外ファイルも含むため復元不可。
if echo "$cmd" | grep -qiE 'rm[[:space:]]+-[[:alpha:]]*r[[:alpha:]]*'; then
  _deny "ERROR: ファイルを再帰的に削除します。削除したファイルは復元できません（git 管理外のファイルも含みます）。実行したい場合はターミナルで手動実行してください: $cmd"
fi

# shred: ファイルを上書き削除。git 管理下でも内容が復元不可。
if echo "$cmd" | grep -qiE '(^|[|;&])[[:space:]]*(sudo[[:space:]]+)?shred([[:space:]]|$)'; then
  _deny "ERROR: ファイルを上書き削除します。git 管理下でも内容は復元できません。実行したい場合はターミナルで手動実行してください: $cmd"
fi

# xargs rm/unlink/shred: xargs 経由の大量削除。復元不可。
if echo "$cmd" | grep -qiE 'xargs[[:space:]]+(sudo[[:space:]]+)?(rm|unlink|shred)'; then
  _deny "ERROR: xargs 経由でファイルを大量削除します。復元できません。実行したい場合はターミナルで手動実行してください: $cmd"
fi

# find -delete / find -exec rm: find 経由の大量削除。復元不可。
if echo "$cmd" | grep -qiE 'find[[:space:]].*-delete|find[[:space:]].*-exec[[:space:]]+rm'; then
  _deny "ERROR: find の検索結果を大量削除します。復元できません。実行したい場合はターミナルで手動実行してください: $cmd"
fi

# DROP TABLE: テーブルとデータを完全削除。バックアップなしでは復元不可。
if echo "$cmd" | grep -qiE 'DROP[[:space:]]+TABLE'; then
  _deny "ERROR: テーブルとそのデータを完全に削除します。バックアップなしでは復元できません。実行したい場合はターミナルで手動実行してください: $cmd"
fi

# DROP DATABASE: データベース全体を削除。バックアップなしでは復元不可。
if echo "$cmd" | grep -qiE 'DROP[[:space:]]+DATABASE'; then
  _deny "ERROR: データベース全体を削除します。バックアップなしでは復元できません。実行したい場合はターミナルで手動実行してください: $cmd"
fi

# curl/wget | sh/bash: リモートスクリプトをダウンロードして即座に実行。内容未確認の実行はセキュリティリスク。
if echo "$cmd" | grep -qiE '(curl|wget).*\|.*(sh|bash)'; then
  _deny "ERROR: リモートスクリプトをダウンロードして即座に実行します。内容未確認の実行はシステムが危険にさらされます。スクリプトの内容を確認してからターミナルで手動実行してください: $cmd"
fi

exit 0
