#!/usr/bin/env bash
# track-edited-files / *-edited-files Cursor アダプタの回帰テスト
#
# 守りたい不変条件:
#   1. postToolUse の track アダプタは conversation_id を session_id として記録し、出力しない。
#   2. 対象外の拡張子（.txt）は記録しない。
#   3. stop の入力変換は conversation_id → session_id、workspace_roots[0] → cwd、
#      loop_count > 0 → stop_hook_active に対応づける。
#   4. stop の出力変換は decision: block の reason だけを followup_message にし、
#      無出力・suppressOutput では何も出さない。
#   5. 未処理ファイルが無ければ stop アダプタ 3 本はいずれも何も出さない。
#   6. textlint の残エラーがある .md は 1 回目の stop で followup_message を返し、
#      loop_count > 0 の 2 回目では返さない（差し戻しは 1 回）。

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ADAPTERS="$SCRIPT_DIR/../hooks/adapters"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=../hooks/lib/cursor-io.sh
source "$SCRIPT_DIR/../hooks/lib/cursor-io.sh"

TMP=$(mktemp -d)
trap 'find "$TMP" -mindepth 1 -delete 2>/dev/null; rmdir "$TMP" 2>/dev/null' EXIT
export EDITED_FILES_ROOT="$TMP/edited-files"
CID="cursor-edited-files-test"

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); printf 'ok   - %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL - %s\n' "$1"; }

# T1: track アダプタは conversation_id 単位で記録し、出力しない
OUT=$(jq -nc --arg c "$CID" --arg w "$ROOT" --arg p "$ROOT/README.md" \
  '{conversation_id:$c, cwd:$w, tool_input:{path:$p}}' | bash "$ADAPTERS/track-edited-files.sh")
if [ -z "$OUT" ] && grep -qx "$ROOT/README.md" "$EDITED_FILES_ROOT/$CID/files" 2>/dev/null; then
  ok "T1 track は conversation_id 単位で記録し出力しない"
else
  fail "T1 track は conversation_id 単位で記録し出力しない (out=$OUT)"
fi

# T2: .txt は記録しない
jq -nc --arg c "$CID" --arg w "$ROOT" --arg p "$TMP/note.txt" \
  '{conversation_id:$c, cwd:$w, tool_input:{path:$p}}' | bash "$ADAPTERS/track-edited-files.sh" >/dev/null
if ! grep -q 'note.txt' "$EDITED_FILES_ROOT/$CID/files"; then
  ok "T2 .txt は記録しない"
else
  fail "T2 .txt は記録しない"
fi

# T3: stop 入力の変換
CONV=$(jq -nc --arg c "$CID" --arg w "$ROOT" \
  '{conversation_id:$c, workspace_roots:[$w], loop_count:1, status:"completed", cursor_version:"1.0"}' \
  | cursor_io_stop_to_claude_json)
if [ "$(jq -r '.session_id' <<<"$CONV")" = "$CID" ] \
  && [ "$(jq -r '.cwd' <<<"$CONV")" = "$ROOT" ] \
  && [ "$(jq -r '.stop_hook_active' <<<"$CONV")" = "true" ]; then
  ok "T3 stop 入力を session_id / cwd / stop_hook_active に変換する"
else
  fail "T3 stop 入力の変換 ($CONV)"
fi
CONV0=$(jq -nc '{conversation_id:"x", workspace_roots:["/tmp"], loop_count:0}' | cursor_io_stop_to_claude_json)
if [ "$(jq -r '.stop_hook_active' <<<"$CONV0")" = "false" ]; then
  ok "T3b loop_count 0 は stop_hook_active false"
else
  fail "T3b loop_count 0 は stop_hook_active false ($CONV0)"
fi

# T4: stop 出力の変換（サブシェルで実行する。関数は exit するため）
OUT=$( (cursor_io_emit_claude_stop '{"decision":"block","reason":"直してください"}') )
if [ "$(jq -r '.followup_message' <<<"$OUT")" = "直してください" ]; then
  ok "T4 block の reason を followup_message にする"
else
  fail "T4 block の reason を followup_message にする ($OUT)"
fi
OUT=$( (cursor_io_emit_claude_stop '') )
OUT2=$( (cursor_io_emit_claude_stop '{"suppressOutput": true}') )
if [ -z "$OUT" ] && [ -z "$OUT2" ]; then
  ok "T4b 無出力・suppressOutput は何も出さない"
else
  fail "T4b 無出力・suppressOutput は何も出さない ($OUT / $OUT2)"
fi

# T5: 未処理ファイルが無ければ stop アダプタは何も出さない
STOP_INPUT=$(jq -nc --arg c "no-files-$CID" --arg w "$ROOT" \
  '{conversation_id:$c, workspace_roots:[$w], loop_count:0, cursor_version:"1.0"}')
for name in format-edited-files textlint-edited-files typecheck-edited-files; do
  OUT=$(printf '%s' "$STOP_INPUT" | bash "$ADAPTERS/$name.sh")
  if [ -z "$OUT" ]; then
    ok "T5 $name は未処理ファイル無しで出力しない"
  else
    fail "T5 $name は未処理ファイル無しで出力しない ($OUT)"
  fi
done

# T6: textlint 残エラーは 1 回目だけ followup_message を返す（dotfiles の textlint がある場合のみ）
if [ -x "$ROOT/node_modules/.bin/textlint" ]; then
  MD="$ROOT/cursor/tests/.edited-files-adapters-tmp.md"
  printf '# 見出し\n\nこれは文である。これは文です。だから正しい。\n' > "$MD"
  CID6="textlint-$CID"
  jq -nc --arg c "$CID6" --arg w "$ROOT" --arg p "$MD" \
    '{conversation_id:$c, cwd:$w, tool_input:{path:$p}}' | bash "$ADAPTERS/track-edited-files.sh" >/dev/null
  FIRST=$(jq -nc --arg c "$CID6" --arg w "$ROOT" '{conversation_id:$c, workspace_roots:[$w], loop_count:0, cursor_version:"1.0"}' \
    | bash "$ADAPTERS/textlint-edited-files.sh")
  jq -nc --arg c "$CID6" --arg w "$ROOT" --arg p "$MD" \
    '{conversation_id:$c, cwd:$w, tool_input:{path:$p}}' | bash "$ADAPTERS/track-edited-files.sh" >/dev/null
  SECOND=$(jq -nc --arg c "$CID6" --arg w "$ROOT" '{conversation_id:$c, workspace_roots:[$w], loop_count:1, cursor_version:"1.0"}' \
    | bash "$ADAPTERS/textlint-edited-files.sh")
  rm -f "$MD"
  if printf '%s' "$FIRST" | jq -e '.followup_message | test("textlint")' >/dev/null 2>&1; then
    ok "T6 1 回目の stop は textlint 残エラーを followup_message で返す"
  else
    fail "T6 1 回目の stop は textlint 残エラーを followup_message で返す ($FIRST)"
  fi
  if [ -z "$SECOND" ]; then
    ok "T6b loop_count > 0 の 2 回目は返さない"
  else
    fail "T6b loop_count > 0 の 2 回目は返さない ($SECOND)"
  fi
else
  printf 'skip - T6 textlint が無いため省略\n'
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
