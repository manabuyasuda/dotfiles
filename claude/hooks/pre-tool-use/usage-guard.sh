#!/usr/bin/env bash
# =============================================================================
# pre-tool-use/usage-guard.sh — コンテキスト/コストの使いすぎをハードブロック
# =============================================================================
# フック  : PreToolUse（全ツール）
# 役割   : 1ツール実行ごとに、statusline.sh が算出した「帯」を読み、red 帯に達して
#          いたらそのツール実行を exit 2 でハードブロックする。Stop ではなく
#          PreToolUse を使うのは、応答完了時ではなく「作業の途中」で止めたいため
#          （Stop で block すると逆に応答が継続してしまい途中停止にならない）。
#          - cost が red   : 従量課金が際限なく増えるのを避けるため一度止めて相談させる
#          - context が red: 劣化が出る前に keep→/compact を促す
#
# 閾値の所在: 閾値（コンテキスト % / コスト円）の判定は statusline.sh に集約してある。
#          このフックは閾値を一切持たず、statusline.sh がキャッシュに書いた
#          ctx_band / cost_band（green/yellow/red）の red 判定だけを行う。
#          こうして「閾値の二重定義 → 片方だけ変えてズレる」再発を構造的に防ぐ。
#
# データ源: ${TMPDIR:-/tmp}/statusline-prev-<session_id>（statusline.sh が毎ターン更新）。
#          statusline.sh とこのフックは同一プロセスツリーの子で TMPDIR を共有する前提。
#          キャッシュが無い（statusline 未実行）場合はフェイルオープン（通過）。
#
# 再発火制御: 同じ red 帯では一度しか止めない（毎ツール止めると作業が進まないため）。
#          警告済みの帯を ${TMPDIR:-/tmp}/usage-guard-<session_id> に記録する。
#          帯が red を外れたらフラグをクリアし、再び red になれば再発火する
#          （/compact で下がってまた上がった、などに追従する）。
#
# 終了コード:
#   0 → 通過（red でない / 警告済み / キャッシュ無し / session_id 無し）
#   2 → ハードブロック（red 帯で未警告）
#
# 入力 : stdin の JSON（.session_id を使う）
# =============================================================================

# jq が無ければ判定できないのでフェイルオープン
command -v jq &>/dev/null || exit 0

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')
[ -z "$session_id" ] && exit 0

CACHE_FILE="${TMPDIR:-/tmp}/statusline-prev-${session_id}"
STATE_FILE="${TMPDIR:-/tmp}/usage-guard-${session_id}"

# statusline がまだ一度も走っていなければ帯が無い。止めずに通す。
[ -f "$CACHE_FILE" ] || exit 0

ctx_band=$(jq -r '.ctx_band // empty' "$CACHE_FILE" 2>/dev/null)
cost_band=$(jq -r '.cost_band // empty' "$CACHE_FILE" 2>/dev/null)

# 前回までに警告済みの帯を読む（無ければ空）
prev_cost_warned=$([ -f "$STATE_FILE" ] && jq -r '.cost_warned // empty' "$STATE_FILE" 2>/dev/null || echo "")
prev_ctx_warned=$([ -f "$STATE_FILE" ] && jq -r '.ctx_warned // empty' "$STATE_FILE" 2>/dev/null || echo "")

# red を外れたらフラグをクリア（次に red へ戻ったら再発火できるようにする）
new_cost_warned="$prev_cost_warned"
new_ctx_warned="$prev_ctx_warned"
[ "$cost_band" != "red" ] && new_cost_warned=""
[ "$ctx_band" != "red" ] && new_ctx_warned=""

# 発火対象を決める。コスト（青天井防止）を優先し、1回の呼び出しで1メッセージに絞る。
# 片方を出した呼び出しでは他方の warned を更新しない（次の呼び出しで順に出す）。
fire=""
msg=""
if [ "$cost_band" = "red" ] && [ "$prev_cost_warned" != "red" ]; then
  fire="cost"
  new_cost_warned="red"
  msg="STOP: 累計コストが赤帯の閾値に達しました。従量課金が際限なく増えるのを避けるため、ここで一度作業を止めます。WHY: コスト上限の歯止めです。FIX: 残作業が本当に必要か・進め方を変えられないかをユーザーと検討し、続行する場合はユーザーに明示的な続行可否を確認してから再開してください。"
elif [ "$ctx_band" = "red" ] && [ "$prev_ctx_warned" != "red" ]; then
  fire="ctx"
  new_ctx_warned="red"
  msg="STOP: コンテキスト使用率が赤帯の閾値に達しました。auto-compact（95%）を待つと要約の質が落ち応答も劣化します。WHY: 劣化が出る前に圧縮するためです。FIX: keep スキルで重要事項を保存してから /compact を検討するようユーザーに促してください。"
fi

# 状態を保存（発火有無にかかわらず現在の帯状況を反映する）
jq -n --arg c "$new_cost_warned" --arg x "$new_ctx_warned" \
  '{"cost_warned": $c, "ctx_warned": $x}' > "$STATE_FILE" 2>/dev/null

# 発火しないなら通過
[ -z "$fire" ] && exit 0

# branch-guard.sh と同じ deny 形式で Claude にフィードバックしつつハードブロック
jq -n --arg msg "$msg" \
  '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$msg}}'
exit 2
