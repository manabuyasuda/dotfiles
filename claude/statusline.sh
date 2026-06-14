#!/usr/bin/env bash
# Claude Code のステータスライン表示スクリプト
#
# Claude Code が起動するたびに JSON を stdin に渡してくる。
# このスクリプトはその JSON を読み取り、複数行のテキストを stdout に出力する。
# Claude Code はその出力を画面下部のステータスバーに表示する。
#
# 表示を3つのグループに分け、グループごとに改行する。
#   1行目: モデルとブランチ（何で・どこで動いているか）
#   2行目: コンテキスト使用率（どれだけ詰まっているか）
#   3行目: 使用量または費用（どれだけ使ったか）
#
# 3行目はプランで内容が変わる。
#   サブスク（Pro / Max）: 5h / 7d の使用量
#   従量課金            : 円と年収換算
#
# 表示例（従量課金）:
#   🤖 Sonnet 4.6 200K   🌿 feature/salary-statusline
#   📈 45.2% (+3.2)
#   💴 ¥1,273 (+73)   年収換算 約160万円
#
# 表示例（Max / Pro プラン）:
#   🤖 Sonnet 4.6 200K   🌿 main
#   📈 45.0% (+3.2)
#   🕐 5h: 23% 🔄14:30   📅 7d: 41% 🔄6/19 21:00

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

# サブスク使用量（5h / 7d）の色分け閾値（%）
# この値以上で黄色、次の値以上で赤になる。5h と 7d で閾値を分ける。
# 7d ウィンドウは数日かけてしか回復しないため、同じ使用率でも 5h より切迫度が
# 高い。よって 7d の方を低い閾値で警告色（黄・赤）に切り替える。
USAGE_5H_YELLOW=50   # 5h: 50% 以上 → 黄色
USAGE_5H_RED=80      # 5h: 80% 以上 → 赤
USAGE_7D_YELLOW=40   # 7d: 40% 以上 → 黄色
USAGE_7D_RED=70      # 7d: 70% 以上 → 赤

# 年収換算の設定
# 「いまのペースで1年間使い続けたら年収いくらの人を貼り付けているのと同じか」を出す
WORK_HOURS_PER_YEAR=2000   # 年間労働時間。時給を年収に引き伸ばす係数
LABOR_COST_FACTOR=1.0      # 1.0=支払い額の年間換算（人件費相当） / 1.4=額面年収相当

# 年収換算の表示ゲート（経過時間ベース）
# 年収換算は rate = 累計コスト / 経過時間 で、経過時間が小さいほど発散して暴れる。
# そこで「経過時間がこの分数に達するまでは年収換算を出さない」ことにする。
# しきい値を超えてから初めて表示するので、擬似時間で下駄を履かせる必要がなくなり、
# 表示値はバイアスのない実ペースになる（旧 RATE_PRIOR_HOURS と ~ マークは廃止）。
# しきい値の金額換算はペース次第で変わる（時間ゲートにする理由そのもの）。
# 分単位の整数で定義し、ミリ秒の整数比較で判定する（浮動小数の丸めに依存しない）。
RATE_MIN_ELAPSED_MIN=10   # 10分（推奨）。5 に下げれば早く表示されるが序盤の揺れが残る

# アイコン定義
# 端末やフォントに合わせて差し替えられるよう、ここにまとめて定義する
ICON_MODEL="🤖"   # モデル
ICON_BRANCH="🌿"  # ブランチ
ICON_CTX="📈"     # コンテキスト使用率（折れ線グラフ）
ICON_5H="🕐"      # 5時間ウィンドウ
ICON_7D="📅"      # 7日間ウィンドウ
ICON_RESET="🔄"   # リセット時刻
ICON_JPY="💴"     # 日本円

# =============================================================================
# ANSI カラーコード
# \033[Xm という形式でターミナルの文字色を変える制御文字
# RESET を末尾に付けないと、それ以降の出力もその色のままになる
# =============================================================================
RESET='\033[0m'    # 色をリセット（必ず色の末尾に付ける）
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'

# 数字に3桁区切りのカンマを入れる（例: 1273 → 1,273）
# 数字を逆順にして3文字ごとにカンマを挿入し、再度逆順に戻す
_group_digits() {
  echo "$1" | rev | sed 's/[0-9]\{3\}/&,/g' | rev | sed 's/^,//'
}

# プラン判別: rate_limits があればサブスク（Pro / Max）、なければ従量課金
# rate_limits はサブスクでのみ最初の API 応答後に現れるフィールド。
# cost.total_cost_usd はサブスクでも公開 API レートでの推定額が入り 0 にならないため、
# 金額の大小ではサブスクと従量課金を判別できない。判定軸は rate_limits の有無にする。
HAS_LIMITS=$(echo "$input" | jq -r 'if .rate_limits then "yes" else "no" end')

# 各行を組み立てて配列に積む。最後に改行で結合して出力する
lines=()

# =============================================================================
# 1行目: モデル名 + コンテキストサイズ + ブランチ
# 例: 🤖 Sonnet 4.6 200K   🌿 feature/salary-statusline
# =============================================================================
line1_parts=()

MODEL=$(echo "$input" | jq -r '.model.display_name // empty')
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
if [ -n "$MODEL" ]; then
  MODEL_STR="$MODEL"
  if [ -n "$CTX_SIZE" ]; then
    # トークン数（例: 200000）を K 単位（例: 200K）に変換して表示する
    CTX_SIZE_K=$(( CTX_SIZE / 1000 ))
    MODEL_STR+=" ${CTX_SIZE_K}K"
  fi
  line1_parts+=("${ICON_MODEL} ${MODEL_STR}")
fi

# ブランチ名を workspace.current_dir 起点に git から取得する
# 取得できない場合（git 管理下でない、detached HEAD など）は表示しない
CUR_DIR=$(echo "$input" | jq -r '.workspace.current_dir // empty')
if [ -n "$CUR_DIR" ]; then
  BRANCH=$(git -C "$CUR_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
  # detached HEAD では "HEAD" が返るので、その場合は表示しない
  if [ -n "$BRANCH" ] && [ "$BRANCH" != "HEAD" ]; then
    line1_parts+=("${ICON_BRANCH} ${BRANCH}")
  fi
fi

# グループ間は3スペースで区切る
if [ ${#line1_parts[@]} -gt 0 ]; then
  line1=""
  for p in "${line1_parts[@]}"; do
    [ -n "$line1" ] && line1+="   "
    line1+="$p"
  done
  lines+=("$line1")
fi

# =============================================================================
# 2行目: コンテキスト使用率（前回との差分付き）
# 例: 📈 45.2% (+3.2)
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

  lines+=("${CTX_COLOR}${ICON_CTX} ${WARN}${CTX_FMT}%${CTX_DIFF_STR}${RESET}")
fi

# =============================================================================
# 3行目（サブスク）: 使用量制限
# 例: 🕐 5h: 23% 🔄14:30   📅 7d: 41% 🔄6/19 21:00
#
# rate_limits フィールドは Claude.ai サブスクリプション（Pro / Max）のみ提供される。
# 5 時間ウィンドウ: 直近 5 時間の使用量。短時間の集中作業で上限に当たりやすい
# 7 日間ウィンドウ: 直近 7 日間の使用量。週単位の総量を管理する
# 🔄 のあとはそのウィンドウがリセットされる時刻（ローカル時間）。
# 5h は時刻のみ、7d は数日先になり得るので「M/D HH:MM」と日付付きで表示する。
#
# 色分け: 5h / 7d それぞれの使用率に応じて緑→黄→赤に変える（_usage_color）。
# コンテキスト行と同じく「黄＝注意・赤＝危険」の意味をそろえる。閾値は 5h と
# 7d で分け、回復の遅い 7d を低めの閾値で警告色にする（USAGE_5H_* / USAGE_7D_*）。
# =============================================================================

# 使用率（整数 %）と閾値から色（ANSI コード）を返す関数
# 第2引数以上で黄色、第3引数以上で赤、いずれも下回れば緑を返す。
# 5h と 7d で異なる閾値を渡せるよう、閾値は引数で受け取る。
_usage_color() {
  local pct="$1" yellow="$2" red="$3"
  if (( pct >= red )); then
    printf '%s' "$RED"
  elif (( pct >= yellow )); then
    printf '%s' "$YELLOW"
  else
    printf '%s' "$GREEN"
  fi
}

# Unix epoch（1970年1月1日からの秒数）をローカル時刻に変換する関数
# 第2引数に strftime 書式を渡す（省略時は時刻のみ）。
# 5h ウィンドウはリセットが5時間以内なので時刻だけで一意に定まるが、
# 7d ウィンドウは数日先になり得るため、呼び出し側で日付付きの書式を渡す。
# macOS は date -r、Linux は date -d @ という異なる書式を使うため両方に対応する
_fmt_resets_at() {
  local epoch="$1"
  local fmt="${2:-+%H:%M}"
  [ -z "$epoch" ] && return
  if date -r "$epoch" &>/dev/null 2>&1; then
    date -r "$epoch" "$fmt"       # macOS
  else
    date -d "@$epoch" "$fmt" 2>/dev/null  # Linux
  fi
}

if [ "$HAS_LIMITS" = "yes" ]; then
  usage_parts=()

  FIVE_H_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
  FIVE_H_AT=$(echo "$input"  | jq -r '.rate_limits.five_hour.resets_at // empty')
  SEVEN_D_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
  SEVEN_D_AT=$(echo "$input"  | jq -r '.rate_limits.seven_day.resets_at // empty')

  if [ -n "$FIVE_H_PCT" ]; then
    FIVE_H_INT=$(printf '%.0f' "$FIVE_H_PCT")
    FIVE_H_TIME=$(_fmt_resets_at "$FIVE_H_AT")
    FIVE_H_STR="${ICON_5H} 5h: ${FIVE_H_INT}%"
    [ -n "$FIVE_H_TIME" ] && FIVE_H_STR+=" ${ICON_RESET}${FIVE_H_TIME}"
    FIVE_H_COLOR=$(_usage_color "$FIVE_H_INT" "$USAGE_5H_YELLOW" "$USAGE_5H_RED")
    usage_parts+=("${FIVE_H_COLOR}${FIVE_H_STR}${RESET}")
  fi

  if [ -n "$SEVEN_D_PCT" ]; then
    SEVEN_D_INT=$(printf '%.0f' "$SEVEN_D_PCT")
    # 7d は数日先にリセットされ得るので「M/D HH:MM」と日付付きで表示する
    SEVEN_D_TIME=$(_fmt_resets_at "$SEVEN_D_AT" "+%-m/%-d %H:%M")
    SEVEN_D_STR="${ICON_7D} 7d: ${SEVEN_D_INT}%"
    [ -n "$SEVEN_D_TIME" ] && SEVEN_D_STR+=" ${ICON_RESET}${SEVEN_D_TIME}"
    SEVEN_D_COLOR=$(_usage_color "$SEVEN_D_INT" "$USAGE_7D_YELLOW" "$USAGE_7D_RED")
    usage_parts+=("${SEVEN_D_COLOR}${SEVEN_D_STR}${RESET}")
  fi

  # 各パーツ（5h / 7d）は個別に色付け済みなので、ここでは色を付けず連結のみ行う
  if [ ${#usage_parts[@]} -gt 0 ]; then
    usage_line=""
    for p in "${usage_parts[@]}"; do
      [ -n "$usage_line" ] && usage_line+="   "
      usage_line+="$p"
    done
    lines+=("$usage_line")
  fi
fi

# =============================================================================
# 3行目（従量課金）: 費用（円のみ）+ 年収換算
# 例: 💴 ¥1,273 (+73)   年収換算 約160万円
#
# total_cost_usd はセッション開始からの累計コスト（USD）。従量課金では実際の支払い額。
# 従量課金時はドルを出さず円のみを表示し、円の差分には通貨記号を付けない。
# 色の閾値（COST_YELLOW_JPY / COST_RED_JPY を JPY_PER_USD でドル換算した値を使う）。
# =============================================================================
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
if [ "$HAS_LIMITS" = "no" ] && [ -n "$COST" ] && (( $(echo "$COST > 0" | bc -l) )); then

  # コストの色を決める（bc -l は小数の比較のために必要）
  if (( $(echo "$COST >= $COST_RED" | bc -l) )); then
    COST_COLOR=$RED
  elif (( $(echo "$COST >= $COST_YELLOW" | bc -l) )); then
    COST_COLOR=$YELLOW
  else
    COST_COLOR=$GREEN
  fi

  # 円表示（3桁区切り、小数切り捨て）
  COST_JPY_NUM=$(echo "$COST * $JPY_PER_USD" | bc -l | cut -d. -f1)
  COST_JPY="${ICON_JPY} ¥$(_group_digits "$COST_JPY_NUM")"

  # 前回値をキャッシュから読み込んで差分を計算する（通貨記号は付けない）
  PREV_COST=$([ -f "$CACHE_FILE" ] && jq -r '.cost // empty' "$CACHE_FILE" 2>/dev/null || echo "")
  COST_JPY_DIFF_STR=""
  if [ -n "$PREV_COST" ] && (( $(echo "$PREV_COST > 0" | bc -l) )); then
    DIFF_JPY=$(echo "($COST - $PREV_COST) * $JPY_PER_USD" | bc -l | cut -d. -f1)
    # 同一セッション内では増える一方なので符号は常に + になる
    COST_JPY_DIFF_STR=" (+$(_group_digits "$DIFF_JPY"))"
  fi

  cost_line="${COST_COLOR}${COST_JPY}${COST_JPY_DIFF_STR}${RESET}"

  # 年収換算: いまのペースで1年間使い続けたときの年収帯
  # 経過時間は壁時計（total_duration_ms）を使う。total_api_duration_ms（応答待ち時間）は
  # 考えている時間や打鍵時間を除外して過大評価になるため使わない。
  #
  # rate = 累計コスト / 経過時間 は経過時間が小さいほど発散する。そこで経過時間が
  # RATE_MIN_ELAPSED_H に達するまでは年収換算を出さない（精度ゲート）。しきい値を
  # 超えてから出すので分母が十分に大きく、擬似時間の下駄なしで実ペースを表示できる。
  RATE_MIN_ELAPSED_MS=$(( RATE_MIN_ELAPSED_MIN * 60000 ))
  DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
  if [ -n "$DURATION_MS" ] && (( $(echo "$DURATION_MS > 0" | bc -l) )); then
    ELAPSED_H=$(echo "scale=6; $DURATION_MS / 3600000" | bc -l)
    # 経過時間がしきい値に達していれば年収換算を表示する（未達なら何も足さない）
    # 判定はミリ秒の整数比較なので、ちょうど10分などの境界が厳密に通る
    if (( $(echo "$DURATION_MS >= $RATE_MIN_ELAPSED_MS" | bc -l) )); then
      # 年収（円） = 累計費用 ÷ 経過時間 × 年間労働時間 ÷ 人件費係数 × 為替
      ANNUAL_JPY=$(echo "scale=6; $COST / $ELAPSED_H * $WORK_HOURS_PER_YEAR / $LABOR_COST_FACTOR * $JPY_PER_USD" | bc -l)
      # 10万円単位に四捨五入してチラつきを抑える（+50000 してから整数化）
      ANNUAL_ROUNDED=$(echo "scale=0; ($ANNUAL_JPY + 50000) / 100000 * 100000" | bc -l)
      ANNUAL_MAN=$(( ANNUAL_ROUNDED / 10000 ))
      cost_line+="   年収換算 約${ANNUAL_MAN}万円"
    fi
  fi

  lines+=("$cost_line")
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
# 行が1つもなければ何も出力しない（フィールドがすべて null の場合）
# 各行を改行で結合して出力する。echo -e は \033 などのエスケープを解釈する
# =============================================================================
[ ${#lines[@]} -eq 0 ] && exit 0
out=""
for l in "${lines[@]}"; do
  [ -n "$out" ] && out+=$'\n'
  out+="$l"
done
echo -e "$out"
