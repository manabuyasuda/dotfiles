#!/usr/bin/env bash
# =============================================================================
# pre-tool-use/usage-guard.sh — コンテキストの使いすぎをハードブロック
# =============================================================================
# フック  : PreToolUse（全ツール）
# 役割   : 1ツール実行ごとに、statusline.sh が算出した「コンテキスト帯」を読み、閾値に
#          達していたらそのツール実行を exit 2 でハードブロックする。Stop ではなく
#          PreToolUse を使うのは、応答完了時ではなく「作業の途中」で止めたいため
#          （Stop で block すると逆に応答が継続してしまい途中停止にならない）。
#          - context が yellow/red: 使いすぎで精度が落ちる前に圧縮させる。yellow
#            （早めの /compact の転換点）と red（劣化が出始める）でそれぞれ一度止める。
#
# コストでは止めない: 以前は累計コストが閾値に達したらブロックしていたが、これは従量課金
#          （pay-as-you-go）の青天井を防ぐ前提だった。実際の契約はサブスク（定額）で、
#          トークン使用量に応じた追加課金がないため、コストでツールを止める根拠がない。
#          コスト超過での停止は作業を不当に中断させる誤った停止になるので撤去した。
#          コストの「表示」は statusline.sh 側に残してある（気づきのためで、停止トリガではない）。
#
# 閾値の所在: コンテキスト % の判定は statusline.sh に集約してある。このフックは閾値を
#          一切持たず、statusline.sh がキャッシュに書いた ctx_band（green/yellow/red）
#          だけを見て判定する。こうして「閾値の二重定義 → 片方だけ変えてズレる」再発を
#          構造的に防ぐ。
#
# データ源: ${TMPDIR:-/tmp}/statusline-prev-<session_id>（statusline.sh が毎ターン更新）。
#          statusline.sh とこのフックは同一プロセスツリーの子で TMPDIR を共有する前提。
#          キャッシュが無い（statusline 未実行）場合はフェイルオープン（通過）。
#
# 再発火制御:
#          - context: yellow と red を別々に扱い、各帯で一度だけ止める。直近に止めた
#            帯名を記録し、帯が変わったら（green→yellow, yellow→red など）再び止める。
#            green に戻ったらフラグをクリアし、再上昇で再発火する。
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

# statusline.sh が書いたコンテキスト帯（green/yellow/red）を読む。
ctx_band=$(jq -r '.ctx_band // empty' "$CACHE_FILE" 2>/dev/null)

# 前回までに止めた帯を読む（無ければ空）
prev_ctx_warned=""
if [ -f "$STATE_FILE" ]; then
  prev_ctx_warned=$(jq -r '.ctx_warned // empty' "$STATE_FILE" 2>/dev/null)
fi

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

msg=""
if [ -n "$fire_ctx" ]; then
  if [ "$ctx_band" = "red" ]; then
    msg="STOP: コンテキスト使用率が赤帯の閾値に達しました。auto-compact（95%）を待つと要約の質が落ち応答も劣化します。劣化が出る前に 重要な内容を保存したうえで /compact を検討するようユーザーに促してください。 WHY: 劣化が出る前に圧縮するためです。"
  else
    msg="STOP: コンテキスト使用率が黄帯の閾値に達しました。使いすぎで精度が落ちる前に早めに圧縮し、クリアな状態で作業を続けるため、ここで一度止めます。重要な内容を保存したうえで /compact を検討するようユーザーに促してください。 WHY: 劣化が出る前に圧縮するためです。"
  fi
fi

# 状態を保存（発火有無にかかわらず現在の状況を反映する）
jq -n --arg x "$new_ctx_warned" '{"ctx_warned": $x}' > "$STATE_FILE" 2>/dev/null

# 発火しないなら通過
[ -z "$msg" ] && exit 0

# branch-guard.sh と同じ deny 形式で Claude にフィードバックしつつハードブロック
jq -n --arg msg "$msg" \
  '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$msg}}'
exit 2
