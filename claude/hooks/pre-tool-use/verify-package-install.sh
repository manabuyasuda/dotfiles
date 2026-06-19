#!/usr/bin/env bash
# =============================================================================
# pre-tool-use/verify-package-install.sh — npmパッケージインストール前のセキュリティ検証フラグ確認
# =============================================================================
# フック  : PreToolUse（Bash）
# 役割   : npm install <pkg> / npm i <pkg> / pnpm add <pkg> / yarn add <pkg>
#          を検知し、各パッケージの検証フラグ
#          ($HOME/.claude/cache/verified-packages/<pkg>@<version>) を確認する。
#          未検証 or TTL（24h）切れのパッケージがあれば deny し、
#          セキュリティ検証エージェントの起動を案内する。
#
# 設計（二段階 deny + 検証フラグ方式）:
#   1回目: ユーザーが npm install <pkg>@<ver> → 検証フラグなしで本フックが deny
#          → Claude がメッセージを読みセキュリティ検証エージェントを起動
#          → エージェントが GO 判定なら $HOME/.claude/cache/verified-packages/<pkg>@<ver> を作成
#   2回目: Claude が同じ npm install を再実行 → 検証フラグありで本フックが通過 → bash-guard.sh へ
#
# 検知対象:
#   - npm install <pkg> / npm i <pkg>（パッケージ指定あり）
#   - pnpm add <pkg>
#   - yarn add <pkg>
#
# 除外（本フックでは通過させる。bash-guard.sh が別途処理する）:
#   - npm ci / pnpm install --frozen-lockfile / yarn install --immutable
#   - パッケージ未指定の npm install / pnpm install / yarn install
#   - グローバルフラグ単体（-g / --global / -D / --save-dev など）
#
# バージョン指定について:
#   バージョン未指定（npm install lodash）は「未検証」として deny する。
#   semver 解決で意図しないバージョンが入る可能性があるため、検証エージェントに
#   解決済みバージョンを判定させた上でフラグを作る必要がある。
#
# 入力 : stdin の JSON（tool_input.command）
# 出力 : stdout の JSON（permissionDecision: "deny"）。通過時は何も出力せず exit 0。
# =============================================================================

VERIFIED_CACHE_DIR="$HOME/.claude/cache/verified-packages"
VERIFIED_TTL_SECONDS=$((24 * 60 * 60))

INPUT=$(cat)
COMMAND=$(jq -r '.tool_input.command // ""' <<<"$INPUT")

# 引用符内を除去（誤検知防止）
COMMAND_UNQUOTED=$(echo "$COMMAND" | sed 's/"[^"]*"//g; s/'"'"'[^'"'"']*'"'"'//g')

_deny() {
  jq -n --arg msg "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$msg}}'
  exit 0
}

# コマンドをセグメントに分割する（;・&&・||・&・| のいずれかで切る）
# 引用符内の同記号は事前に COMMAND_UNQUOTED で除去済みのため、ここでは単純分割でよい。
# 長い演算子（&&・||）を先にマッチさせるため alternation の順序に注意。
split_segments() {
  echo "$1" | sed -E 's/(\|\||&&|;|&|\|)/\n/g'
}

# パッケージマネージャーを判定（セグメント先頭トークンが対象 PM・サブコマンドの組み合わせか）
# sfw <pm> ... のように sfw でラップされている場合は sfw を取り除いてから判定する
detect_pm() {
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

# セグメントからパッケージ指定を抽出（フラグ除外）
extract_packages() {
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
  local args=() arg
  for arg in $after; do
    [[ "$arg" =~ ^- ]] && continue
    args+=("$arg")
  done
  printf '%s\n' "${args[@]}"
}

# 全セグメントを舐める。複数の install 系コマンドが連結されていれば、それぞれから対象を抽出する
DETECTED_PM=""
PACKAGES=()
while IFS= read -r seg; do
  [[ -z "$seg" ]] && continue
  pm=$(detect_pm "$seg")
  [[ -z "$pm" ]] && continue
  DETECTED_PM="$pm"
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] && PACKAGES+=("$pkg")
  done < <(extract_packages "$seg" "$pm")
done < <(split_segments "$COMMAND_UNQUOTED")

[[ -z "$DETECTED_PM" ]] && exit 0
PM="$DETECTED_PM"

# パッケージ指定なし → 本フックの対象外。bash-guard.sh の判定に委ねる
[[ ${#PACKAGES[@]} -eq 0 ]] && exit 0

# スコープ付き名 (@scope/name) の / を %2F にエンコード
_encode_slash() {
  echo "$1" | sed 's|/|%2F|g'
}

# mtime から経過秒を取得（BSD/GNU 両対応）
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
    # バージョン未指定 → 未検証
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

# deny メッセージを組み立て
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
