#!/usr/bin/env bash
# Claude Code のステータスライン表示スクリプト
#
# Claude Code が起動するたびに JSON を stdin に渡してくる。
# このスクリプトはその JSON を読み取り、1行のテキストを stdout に出力する。
# Claude Code はその出力を画面下部のステータスバーに表示する。
#
# 表示例（API 従量課金）:
#   [claude-sonnet-4-6 200K] ctx: 45.0% (+3.2), $7.96 (+$0.05), ¥1,274 (+¥8)
#
# 表示例（Max / Pro プラン）:
#   [claude-sonnet-4-6 200K] ctx: 45.0% (+3.2), 5h: 23% →14:30, 7d: 41% →月曜

# jq がインストールされていなければ警告して終了する
# jq は JSON を解析するためのコマンドラインツール
if ! command -v jq &>/dev/null; then
  echo "jq not found"
  exit 0
fi

# Claude Code から渡された JSON をすべて読み込む
input=$(cat)

# セッション ID を取得する（差分計算のキャッシュファイル名に使う）
# セッションをまたいで値がリセットされないよう、セッションごとに別ファイルにする
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')
CACHE_FILE="${TMPDIR:-/tmp}/statusline-prev-${SESSION_ID}"

# =============================================================================
# カスタマイズ可能な設定
# =============================================================================

# 為替レート（円/ドル）。相場が変わったらここだけ更新する
JPY_PER_USD=160

# コスト色分けの閾値（円建て）
# この金額を超えると黄色、次の金額を超えると赤になる
# ドル換算は JPY_PER_USD から自動計算する
COST_YELLOW_JPY=1600   # ¥1,600 以上 → 黄色
COST_RED_JPY=3200      # ¥3,200 以上 → 赤（黄色の2倍）

# 円をドルに換算して閾値を作る（bc -l は小数計算のため）
COST_YELLOW=$(echo "scale=4; $COST_YELLOW_JPY / $JPY_PER_USD" | bc -l)
COST_RED=$(echo "scale=4; $COST_RED_JPY / $JPY_PER_USD" | bc -l)

# =============================================================================
# ANSI カラーコード
# \033[Xm という形式でターミナルの文字色を変える制御文字
# RESET を末尾に付けないと、それ以降の出力もその色のままになる
# =============================================================================
RESET='\033[0m'    # 色をリセット（必ず色の末尾に付ける）
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'

# 表示パーツを配列に積んでいき、最後にスペース区切りで結合して出力する
parts=()

# =============================================================================
# モデル名 + コンテキストウィンドウサイズ
# 例: [claude-sonnet-4-6 200K]
# =============================================================================
MODEL=$(echo "$input" | jq -r '.model.display_name // empty')
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
if [ -n "$MODEL" ]; then
  MODEL_STR="$MODEL"
  if [ -n "$CTX_SIZE" ]; then
    # トークン数（例: 200000）を K 単位（例: 200K）に変換して表示する
    CTX_SIZE_K=$(( CTX_SIZE / 1000 ))
    MODEL_STR+=" ${CTX_SIZE_K}K"
  fi
  parts+=("[${MODEL_STR}]")
fi

# =============================================================================
# コンテキスト使用率（前回との差分付き）
# 例: ctx: 76.0% (+3.2),
#
# used_percentage = 現在の入力トークン数 ÷ コンテキストウィンドウサイズ × 100
# 色の閾値:
#   50% 未満 → 緑（フル精度。Claude はセッション全体に非圧縮でアクセスできる）
#   50〜74%  → 黄（能動的 /compact を検討すべき転換点。ここで圧縮すると要約の質が高い）
#   75% 以上 → 赤 + ⚠️（劣化が体感で出始めるライン。auto-compact は 95% なので手遅れ気味）
# =============================================================================
CTX=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$CTX" ]; then
  # 小数第1位まで表示（例: 75.3）。色の閾値判定には整数部を使う
  CTX_FMT=$(printf '%.1f' "$CTX")
  CTX_INT=$(printf '%.0f' "$CTX")

  if (( CTX_INT >= 75 )); then
    CTX_COLOR=$RED
    WARN="⚠️ "
  elif (( CTX_INT >= 50 )); then
    CTX_COLOR=$YELLOW
    WARN=""
  else
    CTX_COLOR=$GREEN
    WARN=""
  fi

  # 前回の値をキャッシュファイルから読み込んで差分を計算する
  # キャッシュファイルがなければ（初回）差分は表示しない
  PREV_CTX=$([ -f "$CACHE_FILE" ] && jq -r '.ctx // empty' "$CACHE_FILE" 2>/dev/null || echo "")
  CTX_DIFF_STR=""
  if [ -n "$PREV_CTX" ]; then
    # bc -l で小数第1位まで差分を計算し、符号を付ける（/compact 後はマイナスになる）
    DIFF=$(printf '%.1f' "$(echo "$CTX - $PREV_CTX" | bc -l)")
    if (( $(echo "$DIFF >= 0" | bc -l) )); then
      CTX_DIFF_STR=" (+${DIFF})"
    else
      CTX_DIFF_STR=" (${DIFF})"
    fi
  fi

  # 末尾のカンマは次のパーツとの区切り
  parts+=("${CTX_COLOR}ctx: ${WARN}${CTX_FMT}%${CTX_DIFF_STR},${RESET}")
fi

# =============================================================================
# 使用量制限（Max / Pro プランのみ表示される）
# 例: 5h: 23% →14:30, 7d: 41% →07:40
#
# rate_limits フィールドは Claude.ai サブスクリプション（Pro / Max）のみ提供される。
# API 従量課金では存在しないため、フィールドがなければこのセクションは表示しない。
#
# 5 時間ウィンドウ: 直近 5 時間の使用量。短時間の集中作業で上限に当たりやすい
# 7 日間ウィンドウ: 直近 7 日間の使用量。週単位の総量を管理する
# →HH:MM はそのウィンドウがリセットされる時刻（ローカル時間）
# =============================================================================

# Unix epoch（1970年1月1日からの秒数）をローカル時刻の HH:MM に変換する関数
# macOS は date -r、Linux は date -d @ という異なる書式を使うため両方に対応する
_fmt_resets_at() {
  local epoch="$1"
  [ -z "$epoch" ] && return
  if date -r "$epoch" &>/dev/null 2>&1; then
    date -r "$epoch" "+%H:%M"       # macOS
  else
    date -d "@$epoch" "+%H:%M" 2>/dev/null  # Linux
  fi
}

FIVE_H_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_H_AT=$(echo "$input"  | jq -r '.rate_limits.five_hour.resets_at // empty')
SEVEN_D_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
SEVEN_D_AT=$(echo "$input"  | jq -r '.rate_limits.seven_day.resets_at // empty')

if [ -n "$FIVE_H_PCT" ]; then
  FIVE_H_INT=$(printf '%.0f' "$FIVE_H_PCT")
  FIVE_H_TIME=$(_fmt_resets_at "$FIVE_H_AT")
  FIVE_H_STR="5h: ${FIVE_H_INT}%"
  [ -n "$FIVE_H_TIME" ] && FIVE_H_STR+=" →${FIVE_H_TIME}"
  parts+=("${YELLOW}${FIVE_H_STR}${RESET}")
fi

if [ -n "$SEVEN_D_PCT" ]; then
  SEVEN_D_INT=$(printf '%.0f' "$SEVEN_D_PCT")
  SEVEN_D_TIME=$(_fmt_resets_at "$SEVEN_D_AT")
  SEVEN_D_STR="7d: ${SEVEN_D_INT}%"
  [ -n "$SEVEN_D_TIME" ] && SEVEN_D_STR+=" →${SEVEN_D_TIME}"
  parts+=("${YELLOW}${SEVEN_D_STR}${RESET}")
fi

# =============================================================================
# セッションコスト（API 従量課金環境のみ。0 円は表示しない）
# 例: $8.22 (+$0.05), ¥1,315 (+¥8)
#
# total_cost_usd はセッション開始からの累計コスト（USD）。
# セッションをまたいでリセットされる。Max プランでは 0 または null になる。
#
# 色の閾値（COST_YELLOW_JPY / COST_RED_JPY を JPY_PER_USD でドル換算した値を使う）
# =============================================================================
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
if [ -n "$COST" ] && (( $(echo "$COST > 0" | bc -l) )); then

  # コストの色を決める（bc -l は小数の比較のために必要）
  if (( $(echo "$COST >= $COST_RED" | bc -l) )); then
    COST_COLOR=$RED
  elif (( $(echo "$COST >= $COST_YELLOW" | bc -l) )); then
    COST_COLOR=$YELLOW
  else
    COST_COLOR=$GREEN
  fi

  # 前回値をキャッシュから読み込んで差分を計算する
  PREV_COST=$([ -f "$CACHE_FILE" ] && jq -r '.cost // empty' "$CACHE_FILE" 2>/dev/null || echo "")
  COST_USD_DIFF_STR=""
  COST_JPY_DIFF_STR=""
  if [ -n "$PREV_COST" ] && (( $(echo "$PREV_COST > 0" | bc -l) )); then
    DIFF_USD=$(echo "$COST - $PREV_COST" | bc -l)
    DIFF_JPY=$(echo "$DIFF_USD * $JPY_PER_USD" | bc -l | cut -d. -f1)
    COST_USD_DIFF_STR=$(printf '(+$%.2f)' "$DIFF_USD")
    # 3桁区切り: 数字を逆順にして3文字ごとにカンマを挿入し、再度逆順に戻す
    DIFF_JPY_FMT=$(echo "$DIFF_JPY" | rev | sed 's/[0-9]\{3\}/&,/g' | rev | sed 's/^,//')
    COST_JPY_DIFF_STR="(+¥${DIFF_JPY_FMT})"
  fi

  # ドル表示（小数点以下2桁）と円表示（3桁区切り）を組み立てる
  COST_FMT=$(printf '$%.2f' "$COST")
  COST_JPY="¥$(echo "$COST * $JPY_PER_USD" | bc -l | cut -d. -f1 | rev | sed 's/[0-9]\{3\}/&,/g' | rev | sed 's/^,//')"

  # 差分がある場合だけ括弧を付ける（${var:+ ...} は var が空でなければ展開する）
  COST_USD_PART="${COST_FMT}${COST_USD_DIFF_STR:+ ${COST_USD_DIFF_STR}}"
  COST_JPY_PART="${COST_JPY}${COST_JPY_DIFF_STR:+ ${COST_JPY_DIFF_STR}}"
  parts+=("${COST_COLOR}${COST_USD_PART}, ${COST_JPY_PART}${RESET}")
fi

# =============================================================================
# キャッシュ更新
# 現在の ctx と cost を次回の差分計算のためにファイルに保存する
# SESSION_ID をファイル名に含めることでセッション間の混在を防ぐ
# =============================================================================
if [ -n "$SESSION_ID" ]; then
  jq -n \
    --arg ctx "${CTX:-}" \
    --arg cost "${COST:-}" \
    '{"ctx": $ctx, "cost": $cost}' > "$CACHE_FILE"
fi

# =============================================================================
# 出力
# パーツが1つもなければ何も出力しない（フィールドがすべて null の場合）
# ${parts[*]} は配列の全要素をスペース区切りで展開する
# echo -e は \033 などのエスケープシーケンスを解釈する
# =============================================================================
[ ${#parts[@]} -eq 0 ] && exit 0
echo -e "${parts[*]}"
