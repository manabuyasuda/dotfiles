#!/usr/bin/env bash
# Codex ラッパが ask を deny へ落とす変換の回帰テスト
#
# 守りたい不変条件は3つ。
#   1. 取り消せない操作（[DESTRUCTIVE]）と秘密ファイル名の一致（[SECRET_NAME]）は、
#      Codex では deny になる。Codex は ask を無視して実行するため、変換しないと素通りする。
#   2. git push / npm install（NETWORK_WRITE / INSTALL）は deny にならない。
#      これらを止めると Codex で日常の作業ができなくなる。
#   3. 通過するコマンドは何も出力しない。空行を書くと Codex が JSON として読む。
#
# タグは bash-guard.sh の理由文の先頭にある文字列に依存する。文言を変えると
# 変換が静かに止まるため、ここで落として気づけるようにする。
#
# 使い方: bash codex/tests/ask-fallback.test.sh
# 終了コード 0=全テスト成功 / 1=失敗あり

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
WRAP="$ROOT/codex/hooks/wrap/pre-tool-use.sh"

PASS=0
FAIL=0
_ok() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
_ng() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# ラッパ本体を呼ぶ。cursor_io_dotfiles_dir がスクリプトの位置からリポジトリ root を
# 解決するため、$HOME/.codex へのリンクがなくてもリポジトリ内で実行できる。
# Why: 変換の式をテストへ書き写すと、ラッパを変えてもテストが通ってしまう。
_wrapped_decision() {
  local out
  out=$(jq -nc --arg c "$1" '{tool_input:{command:$c},cwd:"/tmp"}' \
    | bash "$WRAP" bash-guard.sh)
  [ -z "$out" ] && { echo "none"; return; }
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"'
}

_expect() {  # $1=コマンド $2=Codexでの期待判定
  local got
  got=$(_wrapped_decision "$1")
  if [ "$got" = "$2" ]; then
    _ok "$1 -> $2"
  else
    _ng "$1 -> 期待 $2 だが $got"
  fi
}

echo "C1: 取り消せない操作は Codex では deny"
_expect 'rm foo.txt' deny
_expect 'git reset --hard HEAD~1' deny

echo "C2: 秘密ファイル名の一致は Codex では deny"
_expect 'grep -rn "process.env" src/' deny
_expect 'cat prod.env' deny

echo "C3: 確認して通していた作業は deny にしない"
# git push を止めると PR が作れず、npm install を止めると依存を追加できない。
# 確認を出せないことの埋め合わせが、作業そのものを不可能にしてはいけない。
_expect 'git push origin feature/foo' ask
_expect 'npm install lodash' ask
# rebase スキルが使う。--force と違いリモートが変わっていれば失敗するため止めない。
_expect 'git push --force-with-lease origin feature/foo' ask

echo "C4: 無害な参照系は何も出力しない"
_expect 'git status' none
_expect 'cat README.md' none

echo "C5: ラッパが通過時に空行を書かない"
# 空行を書くと Codex が JSON として読み、パースエラーになる。
OUT=$(jq -nc '{tool_input:{command:"git status"},cwd:"/tmp"}' | bash "$WRAP" bash-guard.sh)
if [ -z "$OUT" ]; then
  _ok "通過時の出力は空"
else
  _ng "通過時に出力がある: $OUT"
fi

echo ""
echo "PASS: $PASS / FAIL: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
