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

# 引用符内の文字列を除去してパターンマッチングの誤検知を防ぐ
# （例: grep "rm -rf" が rm -rf コマンドとして誤検知されることを防ぐ）
cmd_unquoted=$(echo "$cmd" | sed 's/"[^"]*"//g; s/'"'"'[^'"'"']*'"'"'//g')

# jq の --arg オプションで $cmd を JSON 安全に埋め込む（特殊文字・改行をエスケープ）。
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

# rm -rf / rm -r: ファイルを再帰的に削除。git 管理外ファイルも含むため復元不可。
if echo "$cmd_unquoted" | grep -qiE 'rm[[:space:]]+-[[:alpha:]]*r[[:alpha:]]*'; then
  _deny "ERROR: ファイルを再帰的に削除します。WHY: 削除したファイルは復元できません（git 管理外のファイルも含みます）。FIX: ユーザーが実行したい場合はターミナルで手動実行するよう案内してください: $cmd"
fi

# shred: ファイルを上書き削除。git 管理下でも内容が復元不可。
if echo "$cmd_unquoted" | grep -qiE '(^|[|;&])[[:space:]]*(sudo[[:space:]]+)?shred([[:space:]]|$)'; then
  _deny "ERROR: ファイルを上書き削除します。WHY: git 管理下でも内容は復元できません。FIX: ユーザーが実行したい場合はターミナルで手動実行するよう案内してください: $cmd"
fi

# xargs rm/unlink/shred: xargs 経由の大量削除。復元不可。
if echo "$cmd_unquoted" | grep -qiE 'xargs[[:space:]]+(sudo[[:space:]]+)?(rm|unlink|shred)'; then
  _deny "ERROR: xargs 経由でファイルを大量削除します。WHY: xargs 経由の削除は対象が広範囲に及びやすく、削除後は復元できません。FIX: ユーザーが実行したい場合はターミナルで手動実行するよう案内してください: $cmd"
fi

# find -delete / find -exec rm: find 経由の大量削除。復元不可。
if echo "$cmd_unquoted" | grep -qiE 'find[[:space:]].*-delete|find[[:space:]].*-exec[[:space:]]+rm'; then
  _deny "ERROR: find の検索結果を大量削除します。WHY: find の検索結果は対象が広範囲になりやすく、削除後は復元できません。FIX: ユーザーが実行したい場合はターミナルで手動実行するよう案内してください: $cmd"
fi

# SQL キーワードは SQL ツール経由のコマンドでのみ検出する。
# python3 -c "...TRUNCATE..." や grep "DROP TABLE" のような誤検知を防ぐため、
# psql/mysql 等の SQL ツールが実際に呼び出されているときだけチェックする。
_is_sql_cmd() {
  echo "$cmd" | grep -qE '(^|[|;&])[[:space:]]*(psql|mysql|mysqladmin|sqlite3|clickhouse-client|bq|snowsql)[[:space:]]'
}

# DROP TABLE: テーブルとデータを完全削除。バックアップなしでは復元不可。
if _is_sql_cmd && echo "$cmd" | grep -qiE 'DROP[[:space:]]+TABLE'; then
  _deny "ERROR: テーブルとそのデータを完全に削除します。WHY: バックアップなしでは復元できません。FIX: ユーザーが実行したい場合はターミナルで手動実行するよう案内してください: $cmd"
fi

# DROP DATABASE: データベース全体を削除。バックアップなしでは復元不可。
if _is_sql_cmd && echo "$cmd" | grep -qiE 'DROP[[:space:]]+DATABASE'; then
  _deny "ERROR: データベース全体を削除します。WHY: バックアップなしでは復元できません。FIX: ユーザーが実行したい場合はターミナルで手動実行するよう案内してください: $cmd"
fi

# TRUNCATE: テーブルの全行を削除。WHERE 句で対象を絞れないため意図せず全データが失われる。
if _is_sql_cmd && echo "$cmd" | grep -qiE 'TRUNCATE[[:space:]]'; then
  _deny "ERROR: テーブルの全行を削除します（TRUNCATE は WHERE 句で対象を絞れません）。WHY: バックアップなしでは復元できません。FIX: ユーザーが実行したい場合はターミナルで手動実行するよう案内してください: $cmd"
fi

# DELETE FROM: 行を削除。WHERE 句次第で影響範囲が1行から全行まで変わるため目視確認が必要。
if _is_sql_cmd && echo "$cmd" | grep -qiE 'DELETE[[:space:]]+FROM'; then
  _ask "CAUTION: DELETE FROM を実行しようとしています。WHY: WHERE 句次第で影響範囲が1行から全行まで変わります。FIX: 削除対象のテーブルとWHERE句を確認してください。
コマンド: $cmd"
fi

# git clean: 未追跡ファイルを削除。-x オプションで .gitignore 対象（node_modules, .env 等）も含む。復元不可。
if echo "$cmd_unquoted" | grep -qiE 'git[[:space:]]+clean[[:space:]]+-[[:alpha:]]*[fdx]'; then
  _deny "ERROR: git 管理外のファイルを削除します（-x オプションがある場合は .gitignore 対象も含む）。WHY: 削除したファイルは復元できません。FIX: ユーザーが実行したい場合はターミナルで手動実行するよう案内してください: $cmd"
fi

# curl/wget | sh/bash: リモートスクリプトをダウンロードして即座に実行。内容未確認の実行はセキュリティリスク。
if echo "$cmd_unquoted" | grep -qiE '(curl|wget).*\|.*(sh|bash)'; then
  _deny "ERROR: リモートスクリプトをダウンロードして即座に実行します。WHY: 内容未確認の実行はシステムが危険にさらされます。FIX: ユーザーがスクリプトの内容を確認してから実行したい場合はターミナルで手動実行するよう案内してください: $cmd"
fi

exit 0
