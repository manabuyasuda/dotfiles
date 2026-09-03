#!/usr/bin/env bash
# =============================================================================
# pre-tool-use/push-to-main-guard.sh — 保護ブランチへの git push を deny でブロック
# =============================================================================
# フック  : PreToolUse（Bash）
# 役割   : bash-guard.sh はすべての git push を ask で確認するが、
#          保護ブランチへの push は deny で強制ブロックしたいため、このスクリプトで補完する。
#
# bash-guard.sh との役割分担:
#   - 保護ブランチへの push → このスクリプトが deny（deny が優先）
#   - フィーチャーブランチへの push → bash-guard.sh が ask
#
# 判定範囲: コマンド列を区切り記号（&& || ; | & 改行）で分割し、先頭のコマンド名が git で
#          サブコマンドが push の区間だけを見る。送り先のブランチ名は、その区間の
#          push の引数からのみ取り出して PROTECTED_BRANCHES と照合する。
#
# WHY 区間に限るのか:
#   旧実装はコマンド列の全体を1つの文字列として grep していたため、別のコマンドの引数に
#   保護ブランチ名があるだけで deny になった（フィーチャーブランチの push とPR作成を
#   && で繋ぎ、PR作成側でベースブランチを指定する形）。呼び出しを分ければ回避できるが、
#   拒否メッセージは原因を示さないため毎回の切り分けが要る。さらに、無害なコマンドで
#   拒否が頻発すると deny そのものが信用されなくなり、本当に危険な push を止める力が落ちる。
#
# Why not 引用符の中身を削除するのか:
#   旧実装は誤検知を減らすために引用符の中身ごと削除していた。しかしブランチ名は引用符で
#   囲めるため、囲まれた保護ブランチへの push はブランチ名が消えて素通ししていた（見逃し）。
#   誤検知は呼び出しを分ければ回避できるが、見逃しは回避できない。
#   ここでは中身を消さず、引用符の内側の区切り記号だけを空白へ置き換えて引用符を外す。
#   引用符の中身は文字列でありコマンドの区切りとして働かないので、区切り判定からは外れる。
#
# Why not 正規表現で引数を見るのか:
#   トークン単位に分けることで、git のグローバルオプション（-C dir など）が挟まっても
#   サブコマンドを特定でき、refspec（HEAD:main）の送り先を : の右側として解釈でき、
#   ワイルドカードを含む保護ブランチ名（release/* など）も引数側で照合できる。
#
# 受け入れた限界:
#   入れ子のコマンドは bash -c / sh -c / zsh -c の1段だけ中を見る。xargs・eval・
#   スクリプト経由の実行は検出しない。ヒューリスティックな防御であり、意図的な回避まで
#   止める設計にはしない。旧実装は文字列全体を見ていたため入れ子でも一致したが、
#   その代償が上記の誤検知だった。
#
# 回帰テスト: claude/tests/hook-guard.test.sh（CI の hook-test ワークフローが実行する）
#
# 終了コード:
#   0 → 通過（保護ブランチへの push でない）または deny JSON を出力して終了
#
# 入力 : stdin の JSON（tool_input.command）
# =============================================================================

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../config.sh
source "$HOOKS_DIR/config.sh"

INPUT=$(cat)

# Cursor 互換実行（cursor_version あり）は cursor/hooks.json のアダプタ側で判定済みのため通過する
# shellcheck source=../lib/cursor-compat.sh
source "$(dirname "$0")/../lib/cursor-compat.sh"
# shellcheck source=../lib/decision.sh
source "$(dirname "$0")/../lib/decision.sh"
exit_if_cursor_payload "$INPUT"

# command / cwd を1回の jq でまとめて取得する（同一 stdin を2回 parse しない）。
# command は改行を含み得るため、read（改行で切れる）ではなく NUL 区切り＋mapfile で分割する。
# 各フィールドを NUL 終端して連結し、末尾要素のズレを防ぐ。
# push 元ブランチは「いま作業しているディレクトリ（worktree）」で判定する。
# CLAUDE_PROJECT_DIR は worktree に追従しないため、Claude Code が hook 入力で渡す .cwd を使う。
mapfile -d '' -t _fields < <(
  jq -j '[.tool_input.command // "", .cwd // ""] | join("\u0000") + "\u0000"' <<<"$INPUT"
)
cmd="${_fields[0]:-}"
CWD="${_fields[1]:-}"

# メッセージを関数内に固定することで、複数の呼び出しポイントで同じ文言を保証する
_deny() {
  hook_emit_decision deny PreToolUse "ERROR: 保護ブランチへの直接 push は禁止されています。WHY: レビューなしに変更が保護ブランチへ反映されるリスクがあります。FIX: フィーチャーブランチから Pull Request を作成してください。"
  exit 0
}

# 引用符を外し、引用符の内側の区切り記号だけを空白へ置き換える。
# 中身は残すため、引用符で囲まれたブランチ名も後段の照合で読み取れる。
# エスケープされた引用符（\" など）は解釈しない。ヒューリスティックな防御として許容する。
_unquote() {
  awk '
    BEGIN { q = "" }
    {
      out = ""
      n = length($0)
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if (q == "") {
          if (c == "\"" || c == "\047") { q = c; continue }
          out = out c
        } else {
          if (c == q) { q = ""; continue }
          if (c == "&" || c == "|" || c == ";") { out = out " " } else { out = out c }
        }
      }
      printf "%s", out
      # 引用符の内側で行が終わったなら、その改行は区切りではないので空白にする
      if (q == "") printf "\n"; else printf " "
    }
  '
}

# 1つのコマンド区間が「保護ブランチへの push」かどうかを判定する。
# 戻り値: 0=保護ブランチへの push / 1=それ以外
_is_push_to_protected() {
  local -a toks
  read -ra toks <<< "$1"
  local n=${#toks[@]} i=0 nested=0

  # コマンド名の位置を決める。先頭の環境変数代入（FOO=bar cmd ...）は読み飛ばす。
  while :; do
    while [ "$i" -lt "$n" ] && [[ "${toks[i]}" == *=* && "${toks[i]}" != -* ]]; do i=$((i + 1)); done
    [ "$i" -lt "$n" ] || return 1
    local head="${toks[i]##*/}"
    # bash -c / sh -c / zsh -c は1段だけ中のコマンドを見る
    if [ "$nested" -eq 0 ] && { [ "$head" = bash ] || [ "$head" = sh ] || [ "$head" = zsh ]; }; then
      local c=$((i + 1))
      while [ "$c" -lt "$n" ] && [ "${toks[c]}" != "-c" ]; do c=$((c + 1)); done
      [ "$c" -lt "$n" ] || return 1
      i=$((c + 1)); nested=1; continue
    fi
    break
  done

  [ "${toks[i]##*/}" = git ] || return 1

  # git のグローバルオプションを読み飛ばしてサブコマンドを探す。
  # 値を別トークンで取るオプションは2つ分進める。
  local j=$((i + 1))
  while [ "$j" -lt "$n" ]; do
    case "${toks[j]}" in
      -C|-c|--git-dir|--work-tree|--namespace|--exec-path) j=$((j + 2));;
      -*) j=$((j + 1));;
      *) break;;
    esac
  done
  { [ "$j" -lt "$n" ] && [ "${toks[j]}" = push ]; } || return 1

  # push の引数のうち、フラグでないものを送り先の候補として集める
  local -a refs=()
  local k=$((j + 1)) t
  while [ "$k" -lt "$n" ]; do
    t="${toks[k]}"
    case "$t" in
      -o|--push-option|--receive-pack|--exec) k=$((k + 2)); continue;;
      -*) k=$((k + 1)); continue;;
    esac
    refs+=("$t")
    k=$((k + 1))
  done

  local ref name pattern
  # refspec（src:dst / +src:dst）は : の右側が送り先
  for ref in ${refs[@]+"${refs[@]}"}; do
    name="${ref##*:}"
    name="${name#+}"
    for pattern in "${PROTECTED_BRANCHES[@]}"; do
      # shellcheck disable=SC2053
      if [[ "$name" == $pattern ]]; then
        return 0
      fi
    done
  done

  # 送り先を明示していない（引数なし、またはリモート名だけ）→ 現在ブランチで判定する
  if [ "${#refs[@]}" -le 1 ]; then
    local current
    current=$(git -C "${CWD:-$(pwd)}" branch --show-current 2>/dev/null)
    [ -n "$current" ] || return 1
    for pattern in "${PROTECTED_BRANCHES[@]}"; do
      # shellcheck disable=SC2053
      if [[ "$current" == $pattern ]]; then
        return 0
      fi
    done
  fi

  return 1
}

# 区切り記号で分割して区間ごとに判定する。&& や || は単一文字の置換でも
# 空行に分かれるだけなので、まとめて改行へ置き換える。
while IFS= read -r seg; do
  case "$seg" in
    *[![:space:]]*) ;;
    *) continue;;
  esac
  if _is_push_to_protected "$seg"; then
    _deny
  fi
done <<< "$(printf '%s' "$cmd" | _unquote | tr '|;&' '\n')"

exit 0
