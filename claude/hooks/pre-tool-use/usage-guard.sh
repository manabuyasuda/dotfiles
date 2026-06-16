#!/usr/bin/env bash
# =============================================================================
# pre-tool-use/usage-guard.sh — コンテキスト/コストの使いすぎをハードブロック
# =============================================================================
# フック  : PreToolUse（全ツール）
# 役割   : 1ツール実行ごとに、statusline.sh が算出した「帯/レベル」を読み、閾値に
#          達していたらそのツール実行を exit 2 でハードブロックする。Stop ではなく
#          PreToolUse を使うのは、応答完了時ではなく「作業の途中」で止めたいため
#          （Stop で block すると逆に応答が継続してしまい途中停止にならない）。
#          - context が yellow/red: 使いすぎで精度が落ちる前に圧縮させる。yellow
#            （早めの /compact の転換点）と red（劣化が出始める）でそれぞれ一度止める。
#          - cost が yellow 以上   : 従量課金の青天井を防ぐ。黄帯・赤帯で止めるだけで
#            なく、赤帯を超えても 0.5 倍刻みのレベルごとに何度も止める（止めずに進める
#            といつの間にか高額になるため）。
#
# 閾値の所在: 閾値（コンテキスト % / コスト円 / コストの刻み）の判定は statusline.sh に
#          集約してある。このフックは閾値を一切持たず、statusline.sh がキャッシュに書いた
#          ctx_band（green/yellow/red）と cost_level（0=黄帯未満 /1=黄帯 /2=赤帯 /
#          3=赤帯*1.5 /4=赤帯*2.0 … 0.5 刻み）だけを見て判定する。
#          こうして「閾値の二重定義 → 片方だけ変えてズレる」再発を構造的に防ぐ。
#
# データ源: ${TMPDIR:-/tmp}/statusline-prev-<session_id>（statusline.sh が毎ターン更新）。
#          statusline.sh とこのフックは同一プロセスツリーの子で TMPDIR を共有する前提。
#          キャッシュが無い（statusline 未実行）場合はフェイルオープン（通過）。
#
# 再発火制御:
#          - context: yellow と red を別々に扱い、各帯で一度だけ止める。直近に止めた
#            帯名を記録し、帯が変わったら（green→yellow, yellow→red など）再び止める。
#            green に戻ったらフラグをクリアし、再上昇で再発火する。
#          - cost: 直近に止めたレベルを記録し、現在レベルがそれより上がったときだけ一度
#            止める。これで赤帯*1.5, *2.0 … と段階ごとに一度ずつ止まる。
#          記録は ${TMPDIR:-/tmp}/usage-guard-<session_id>。
#
# 終了コード:
#   0 → 通過（閾値未満 / 警告済み / キャッシュ無し / session_id 無し）
#   2 → ハードブロック（未警告の閾値到達）
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
cost_level=$(jq -r '.cost_level // empty' "$CACHE_FILE" 2>/dev/null)
cur_cost_level=${cost_level:-0}

# 前回までに止めた帯/レベルを読む（無ければ空）
prev_ctx_warned=$([ -f "$STATE_FILE" ] && jq -r '.ctx_warned // empty' "$STATE_FILE" 2>/dev/null || echo "")
prev_cost_level=$([ -f "$STATE_FILE" ] && jq -r '.cost_level // empty' "$STATE_FILE" 2>/dev/null || echo "")
prev_cl=${prev_cost_level:-0}

# --- コンテキスト判定: yellow / red それぞれで一度だけ止める ---
# green/空 はフラグをクリア。yellow→red のように帯が上がったら新しい帯でまた止める。
new_ctx_warned="$prev_ctx_warned"
fire_ctx=""
if [ "$ctx_band" = "yellow" ] || [ "$ctx_band" = "red" ]; then
  if [ "$prev_ctx_warned" != "$ctx_band" ]; then
    fire_ctx="1"
    new_ctx_warned="$ctx_band"
  fi
else
  new_ctx_warned=""
fi

# --- コスト判定: レベルが直近に止めたレベルより上がったら一度だけ止める ---
# レベルは赤帯で打ち止めにせず 0.5 刻みで増えるので、赤帯*1.5, *2.0 … と段階的に止まる。
# 記録は常に現在レベルにする（コストが下がる＝通常起きないが、下がれば再上昇で再発火）。
new_cost_level="$cur_cost_level"
fire_cost=""
if [ "$cur_cost_level" -gt "$prev_cl" ] 2>/dev/null; then
  fire_cost="1"
fi

# --- 各超過の本文（理由＋対処）。両方同時に発火したら1メッセージに連結する ---
cost_msg=""
if [ -n "$fire_cost" ]; then
  if [ "$cur_cost_level" -ge 2 ] 2>/dev/null; then
    cost_msg="累計コストが赤帯の閾値に達しました（赤帯を超えても止めずに進めると、さらに上の段階でも都度止めます）。従量課金が際限なく増えるのを避けるため、ここで一度作業を止めます。残作業が本当に必要か・進め方を変えられないかをユーザーと検討し、続行する場合はユーザーに明示的な続行可否を確認してから再開してください。"
  else
    cost_msg="累計コストが黄帯の閾値に達しました。従量課金が膨らみ赤帯に届く前に、ここで一度作業を止めます。残作業が本当に必要か・進め方を変えられないかをユーザーと検討し、続行する場合はユーザーに明示的な続行可否を確認してから再開してください。"
  fi
fi

ctx_msg=""
if [ -n "$fire_ctx" ]; then
  if [ "$ctx_band" = "red" ]; then
    ctx_msg="コンテキスト使用率が赤帯の閾値に達しました。auto-compact（95%）を待つと要約の質が落ち応答も劣化します。劣化が出る前に 重要な内容を保存したうえで /compact を検討するようユーザーに促してください。"
  else
    ctx_msg="コンテキスト使用率が黄帯の閾値に達しました。使いすぎで精度が落ちる前に早めに圧縮し、クリアな状態で作業を続けるため、ここで一度止めます。重要な内容を保存したうえで /compact を検討するようユーザーに促してください。"
  fi
fi

msg=""
if [ -n "$cost_msg" ] && [ -n "$ctx_msg" ]; then
  msg="STOP: 累計コストとコンテキスト使用率の両方が閾値に達しました。WHY: コストの歯止めと、劣化が出る前の圧縮の両方が必要です。FIX(コスト): ${cost_msg} FIX(コンテキスト): ${ctx_msg}"
elif [ -n "$cost_msg" ]; then
  msg="STOP: ${cost_msg} WHY: コスト上限の歯止めです。"
elif [ -n "$ctx_msg" ]; then
  msg="STOP: ${ctx_msg} WHY: 劣化が出る前に圧縮するためです。"
fi

# 状態を保存（発火有無にかかわらず現在の状況を反映する）
jq -n --arg x "$new_ctx_warned" --arg cl "$new_cost_level" \
  '{"ctx_warned": $x, "cost_level": $cl}' > "$STATE_FILE" 2>/dev/null

# 発火しないなら通過
[ -z "$msg" ] && exit 0

# branch-guard.sh と同じ deny 形式で Claude にフィードバックしつつハードブロック
jq -n --arg msg "$msg" \
  '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$msg}}'
exit 2
