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

# パッケージマネージャーとサブコマンドを判定（引数1個以上が後続することを必須にする）
detect_pm() {
  local c="$1"
  if [[ "$c" =~ (^|[[:space:];|&]|sfw[[:space:]]+)npm[[:space:]]+(install|i)[[:space:]]+[^[:space:]] ]]; then
    echo "npm"
  elif [[ "$c" =~ (^|[[:space:];|&]|sfw[[:space:]]+)pnpm[[:space:]]+add[[:space:]]+[^[:space:]] ]]; then
    echo "pnpm"
  elif [[ "$c" =~ (^|[[:space:];|&]|sfw[[:space:]]+)yarn[[:space:]]+add[[:space:]]+[^[:space:]] ]]; then
    echo "yarn"
  else
    echo ""
  fi
}

PM=$(detect_pm "$COMMAND_UNQUOTED")
[[ -z "$PM" ]] && exit 0

# 引数からパッケージ指定を抽出（フラグ除外）
# pm のサブコマンド (install/i/add) より後ろの引数を対象にする
extract_packages() {
  local c="$1" pm="$2"
  local subcmd_pattern
  case "$pm" in
    npm)  subcmd_pattern='npm[[:space:]]+(install|i)' ;;
    pnpm) subcmd_pattern='pnpm[[:space:]]+add' ;;
    yarn) subcmd_pattern='yarn[[:space:]]+add' ;;
  esac
  # サブコマンド以降の文字列を取り出す
  local after
  after=$(echo "$c" | sed -E "s/.*${subcmd_pattern}[[:space:]]+//")
  # 1行目（;|&以降を切り捨て）
  after=$(echo "$after" | sed -E 's/[[:space:]]*[;|&].*$//')
  # スペースで分割しフラグを除外
  local args=() arg
  for arg in $after; do
    [[ "$arg" =~ ^- ]] && continue
    args+=("$arg")
  done
  printf '%s\n' "${args[@]}"
}

PACKAGES=()
while IFS= read -r line; do
  [[ -n "$line" ]] && PACKAGES+=("$line")
done < <(extract_packages "$COMMAND_UNQUOTED" "$PM")

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
  1. 専用のセキュリティ検証エージェントを起動して、対象パッケージを検証する
  2. 判定が GO の場合、エージェントが \$HOME/.claude/cache/verified-packages/<pkg>@<version> を作成する
  3. 本コマンドを再実行する

バージョンが未指定の場合は、検証エージェントが解決済みバージョンを判定したうえでフラグを作成します。"

_deny "$msg"
