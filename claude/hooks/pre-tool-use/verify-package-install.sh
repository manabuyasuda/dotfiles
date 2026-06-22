#!/usr/bin/env bash
# =============================================================================
# pre-tool-use/verify-package-install.sh — npmパッケージインストール前のセキュリティ検証フラグ確認
# =============================================================================
# フック  : PreToolUse（Bash）
# 役割   : npm install <pkg> / npm i <pkg> / pnpm add <pkg> / yarn add <pkg>
#          を検知し、各パッケージの検証フラグ
#          ($HOME/.claude/cache/verified-packages/<pkg>@<version>) を確認する。
#          未検証 or TTL（24h）切れのパッケージがあれば deny し、
#          セキュリティ検証手順を案内する。
#
# 設計（二段階 deny + 検証フラグ方式）:
#   1回目: ユーザーが npm install <pkg>@<ver> → 検証フラグなしで本フックが deny
#          → LLM がメッセージを読みセキュリティ検証を実施
#          → 安全と判断できたら $HOME/.claude/cache/verified-packages/<pkg>@<ver> を作成
#   2回目: 同じ npm install を再実行 → 検証フラグありで本フックが通過 → bash-guard.sh へ
#
# 判定ロジック:
#   bashlex がある環境では Python (verify-package-install-parse.py) で AST 解析する。
#   無い環境ではフォールバックとして bash で HEREDOC・メッセージ引数を空白マスクしてから
#   1文字走査の state machine で引用符を剥がし、セグメント分割して判定する。
#   bash 単独で HEREDOC・コマンド置換を完全にパースするのは困難なため、
#   フォールバックは「誤検知を最小化する近似」と割り切る
#   （無関係なコマンドまで deny しないことを優先し、取りこぼしは許容する）。
#
# 検知対象:
#   - npm install <pkg> / npm i <pkg>（パッケージ指定あり）
#   - pnpm add <pkg>
#   - yarn add <pkg>
#   - 上記を sfw でラップしたもの
#
# 除外（本フックでは通過させる。bash-guard.sh が別途処理する）:
#   - npm ci / pnpm install --frozen-lockfile / yarn install --immutable
#   - パッケージ未指定の npm install / pnpm install / yarn install
#   - グローバルフラグ単体（-g / --global / -D / --save-dev など）
#
# 入力 : stdin の JSON（tool_input.command）
# 出力 : stdout の JSON（permissionDecision: "deny"）。通過時は何も出力せず exit 0。
# =============================================================================

VERIFIED_CACHE_DIR="$HOME/.claude/cache/verified-packages"
VERIFIED_TTL_SECONDS=$((24 * 60 * 60))
PARSER_SCRIPT="$(dirname "$0")/verify-package-install-parse.py"
# bashlex 専用の venv を優先的に使う。無ければシステム python3 にフォールバック。
# どちらも bashlex が無ければパーサが exit 2 を返し、bash 経路に落ちる。
# テスト用に VERIFY_HOOK_PARSER_PYTHON で経路を明示的に指定できる
# （空文字列を渡せば Python 経路を無効化して bash 経路を強制できる）。
if [[ -n "${VERIFY_HOOK_PARSER_PYTHON+set}" ]]; then
  PARSER_PYTHON="$VERIFY_HOOK_PARSER_PYTHON"
else
  PARSER_VENV="$HOME/.local/share/bashlex-venv/bin/python3"
  if [[ -x "$PARSER_VENV" ]]; then
    PARSER_PYTHON="$PARSER_VENV"
  elif command -v python3 >/dev/null 2>&1; then
    PARSER_PYTHON="python3"
  else
    PARSER_PYTHON=""
  fi
fi

INPUT=$(cat)
COMMAND=$(jq -r '.tool_input.command // ""' <<<"$INPUT")

_deny() {
  jq -n --arg msg "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$msg}}'
  exit 0
}

# -----------------------------------------------------------------------------
# Python (bashlex) 経路
# -----------------------------------------------------------------------------
DETECTED_PM=""
PACKAGES=()
USED_PARSER="bash"

if [[ -f "$PARSER_SCRIPT" && -n "$PARSER_PYTHON" ]]; then
  PARSE_OUTPUT=$(printf '%s' "$COMMAND" | "$PARSER_PYTHON" "$PARSER_SCRIPT" 2>/dev/null)
  PARSE_EXIT=$?
  if [[ $PARSE_EXIT -eq 0 ]]; then
    USED_PARSER="python"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      if [[ "$line" == PM=* ]]; then
        DETECTED_PM="${line#PM=}"
      elif [[ "$line" == PKG=* ]]; then
        PACKAGES+=("${line#PKG=}")
      fi
    done <<<"$PARSE_OUTPUT"
  fi
fi

# -----------------------------------------------------------------------------
# bash フォールバック経路
# -----------------------------------------------------------------------------

# HEREDOC 本体を空白マスクする
# `<<MARKER` / `<<'MARKER'` / `<<"MARKER"` / `<<-MARKER` を検出し、
# 開始行の次行から行頭マーカー（`<<-` の場合はタブ前置あり）までを空白で置換する。
mask_heredocs() {
  awk '
    BEGIN { in_h = 0; marker = ""; allow_tabs = 0 }
    {
      line = $0
      if (in_h) {
        check = line
        if (allow_tabs) sub(/^\t+/, "", check)
        if (check == marker) {
          in_h = 0
          marker = ""
          allow_tabs = 0
          print line
          next
        }
        gsub(/./, " ", line)
        print line
        next
      }
      tmp = line
      while (match(tmp, /<<-?[[:space:]]*("[^"]*"|'\''[^'\'']*'\''|[A-Za-z_][A-Za-z0-9_]*)/)) {
        token = substr(tmp, RSTART, RLENGTH)
        is_dash = (substr(token, 3, 1) == "-")
        m = token
        sub(/^<<-?[[:space:]]*/, "", m)
        gsub(/^["'\'']|["'\'']$/, "", m)
        in_h = 1
        marker = m
        allow_tabs = is_dash
        tmp = substr(tmp, RSTART + RLENGTH)
      }
      print line
    }
  ' <<<"$1"
}

# 引用符内を空白でマスクする state machine。
# `<<<` の HEREDOC ヒアストリング、コマンド置換 `$(...)` の中身も影響を受けるが、
# HEREDOC は mask_heredocs で先に処理済みのため、ここで残るのは通常引数のみと想定する。
mask_quotes() {
  local s="$1" out="" c i
  local in_dq=0 in_sq=0 in_bq=0
  for (( i=0; i<${#s}; i++ )); do
    c="${s:i:1}"
    if (( in_dq==0 && in_sq==0 && in_bq==0 )); then
      case "$c" in
        '"') in_dq=1; out+=" " ;;
        "'") in_sq=1; out+=" " ;;
        '`') in_bq=1; out+=" " ;;
        *) out+="$c" ;;
      esac
    elif (( in_dq )); then
      [[ "$c" == '"' ]] && in_dq=0
      out+=" "
    elif (( in_sq )); then
      [[ "$c" == "'" ]] && in_sq=0
      out+=" "
    elif (( in_bq )); then
      [[ "$c" == '`' ]] && in_bq=0
      out+=" "
    fi
  done
  printf '%s' "$out"
}

split_segments() {
  echo "$1" | sed -E 's/(\|\||&&|;|&|\|)/\n/g'
}

detect_pm_bash() {
  local seg="$1"
  seg=$(echo "$seg" | sed -E 's/^[[:space:]]+//; s/^sfw[[:space:]]+//')
  if [[ "$seg" =~ ^npm[[:space:]]+(install|i)[[:space:]]+[^[:space:]] ]]; then
    echo "npm"
  elif [[ "$seg" =~ ^pnpm[[:space:]]+add[[:space:]]+[^[:space:]] ]]; then
    echo "pnpm"
  elif [[ "$seg" =~ ^yarn[[:space:]]+add[[:space:]]+[^[:space:]] ]]; then
    echo "yarn"
  else
    echo ""
  fi
}

extract_packages_bash() {
  local seg="$1" pm="$2"
  seg=$(echo "$seg" | sed -E 's/^[[:space:]]+//; s/^sfw[[:space:]]+//')
  local subcmd_pattern
  case "$pm" in
    npm)  subcmd_pattern='^npm[[:space:]]+(install|i)[[:space:]]+' ;;
    pnpm) subcmd_pattern='^pnpm[[:space:]]+add[[:space:]]+' ;;
    yarn) subcmd_pattern='^yarn[[:space:]]+add[[:space:]]+' ;;
  esac
  local after
  after=$(echo "$seg" | sed -E "s/${subcmd_pattern}//")
  local arg
  for arg in $after; do
    [[ "$arg" =~ ^- ]] && continue
    echo "$arg"
  done
}

if [[ "$USED_PARSER" != "python" ]]; then
  C0=$(mask_heredocs "$COMMAND")
  C2=$(mask_quotes "$C0")
  while IFS= read -r seg; do
    [[ -z "$seg" ]] && continue
    pm=$(detect_pm_bash "$seg")
    [[ -z "$pm" ]] && continue
    DETECTED_PM="$pm"
    while IFS= read -r pkg; do
      [[ -n "$pkg" ]] && PACKAGES+=("$pkg")
    done < <(extract_packages_bash "$seg" "$pm")
  done < <(split_segments "$C2")
fi

[[ -z "$DETECTED_PM" ]] && exit 0
PM="$DETECTED_PM"

[[ ${#PACKAGES[@]} -eq 0 ]] && exit 0

# -----------------------------------------------------------------------------
# 検証フラグチェック
# -----------------------------------------------------------------------------
_encode_slash() {
  echo "$1" | sed 's|/|%2F|g'
}

_mtime_epoch() {
  local f="$1"
  if stat -f %m "$f" >/dev/null 2>&1; then
    stat -f %m "$f"
  else
    stat -c %Y "$f"
  fi
}

NOW=$(date +%s)
UNVERIFIED=()

for pkg in "${PACKAGES[@]}"; do
  # バージョン指定の検出: 先頭以外に @ があるか
  # @scope/name → @ は先頭の1つだけ → 未指定扱い
  # name@1.2.3 → 先頭以外に @ → 指定あり
  # @scope/name@1.2.3 → 先頭以外にも @ → 指定あり
  local_has_version=0
  if [[ "${pkg:1}" == *@* ]]; then
    local_has_version=1
  fi

  if [[ $local_has_version -eq 0 ]]; then
    UNVERIFIED+=("$pkg (バージョン未指定)")
    continue
  fi

  encoded=$(_encode_slash "$pkg")
  flag="$VERIFIED_CACHE_DIR/$encoded"

  if [[ ! -f "$flag" ]]; then
    UNVERIFIED+=("$pkg")
    continue
  fi

  mtime=$(_mtime_epoch "$flag")
  age=$((NOW - mtime))
  if (( age > VERIFIED_TTL_SECONDS )); then
    UNVERIFIED+=("$pkg (検証から24時間以上経過)")
    continue
  fi
done

[[ ${#UNVERIFIED[@]} -eq 0 ]] && exit 0

list=""
for p in "${UNVERIFIED[@]}"; do
  list+=$'\n  - '"$p"
done

msg="${PM}パッケージのインストール前にセキュリティ検証が必要です。

未検証のパッケージ:${list}

以下の手順を実施してください:
  1. 対象パッケージのセキュリティを検証する（CVE・サプライチェーン・メンテナンス状況・ライセンス・peerDependenciesなど）
  2. 安全に導入できると判断できた場合、\$HOME/.claude/cache/verified-packages/<pkg>@<version> を作成する
  3. 本コマンドを再実行する

バージョンが未指定の場合は、解決済みバージョンを確定したうえでフラグを作成してください。"

_deny "$msg"
