#!/usr/bin/env bash
# deny ルールの回帰テスト
#
# 守りたい不変条件は2つ。
#   1. permissions/deny-rules.json（唯一の情報源）と生成物が一致している。
#      生成物は claude/settings.json の permissions.deny と
#      claude/hooks/pre-tool-use/deny-rules.txt の2つ。
#      片方だけ手で書き換えると保護が静かに外れるため、ずれを失敗として止める。
#   2. bash-guard.sh が deny-rules.txt を実際に適用している。
#      秘密ファイルは cat 以外の読み方でも止まり、秘密情報を書き換える命令も止まる。
#      無害な参照系コマンドは止まらない。
#
# 使い方: bash claude/tests/deny-rules.test.sh
# 終了コード 0=全テスト成功 / 1=失敗あり

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/.." && cd .. && pwd)
BASH_GUARD="$ROOT/claude/hooks/pre-tool-use/bash-guard.sh"

PASS=0
FAIL=0

_ok() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
_ng() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# hook を実行して permissionDecision を返す（出力なし＝通過は "none"）
_decision() {
  local out
  out=$(jq -nc --arg c "$1" '{tool_input:{command:$c},cwd:"/tmp"}' | bash "$BASH_GUARD")
  [ -z "$out" ] && { echo "none"; return; }
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "none"'
}

_expect() {  # $1=コマンド $2=期待する判定
  local got
  got=$(_decision "$1")
  if [ "$got" = "$2" ]; then
    _ok "$1 -> $2"
  else
    _ng "$1 -> 期待 $2 だが $got"
  fi
}

echo "T1: 生成物が permissions/deny-rules.json と同期している"
if python3 "$ROOT/scripts/generate-permissions.py" --check >/dev/null 2>&1; then
  _ok "claude/settings.json と deny-rules.txt が情報源と一致"
else
  _ng "生成物が情報源とずれている（bash scripts/generate-permissions.sh を実行してコミットしてください）"
fi

echo "T2: 秘密ファイルへの操作は cat 以外の読み方でも deny"
SSH_KEY='~/.ssh/id_ed25519'
_expect "cat $SSH_KEY" deny
_expect "head -c 40 $SSH_KEY" deny
_expect "python3 -c \"print(open('$SSH_KEY').read())\"" deny
_expect 'head -5 .env.local' deny
_expect 'grep TOKEN ~/.npmrc' deny
_expect 'cat $HOME/.aws/credentials' deny
_expect 'sed -n 1p /Users/someone/.config/gh/hosts.yml' deny

echo "T3: 秘密情報を書き換える・公開する命令は deny"
_expect 'gh secret set FOO --body bar' deny
_expect 'vault kv put secret/foo bar=baz' deny
_expect 'npm publish' deny
_expect 'security find-generic-password -s github' deny
_expect 'gh api /repos/o/r/actions/secrets/FOO --method DELETE' deny
_expect 'netlify env:set FOO bar' deny

echo "T4: 無害な参照系は通過する"
_expect 'cat README.md' none
_expect 'git status' none
_expect 'gh pr view 1' none
_expect 'npm ci' none

echo "T6: 情報源のglobの範囲外だが秘密ファイルの名前を含む命令は ask"
# deny は claude/settings.json の glob（例 **/.env*）が表す範囲に忠実な一致だけに限る。
# 範囲外は検知を落とさず ask にして、ユーザーが内容を見て判断できるようにする。
_expect 'grep -rn "process.env" src/' ask
_expect 'node -e "console.log(process.env.PATH)"' ask
_expect 'cat .npmrc' ask
_expect 'cat prod.env' ask

echo "T7: 書き方の揺れで素通りしない"
# フラグと値の区切り（空白 / = / 連結）とホームの書き方（~ / $HOME / ${HOME} / 絶対パス）は
# どれも同じ命令を表す。1つでも漏れると、そこだけ保護が外れる。
_expect 'gh api /repos/o/r/x --method=DELETE' deny
_expect 'gh api /repos/o/r/x -XDELETE' deny
_expect 'cat ${HOME}/.aws/credentials' deny
# 複数行のコマンド。行頭の一致を bash の =~ でも取りこぼさないことを確かめる。
_expect 'cd /tmp
vault kv put secret/foo bar=baz' deny

echo "T5: deny の理由に、何を止めたかを示す説明が壊れずに入る"
# ロケールがCのとき bash 5.3 は全角括弧のバイト列を変数名の一部として読む。
# `（$label）` と裸で書くと説明が消え、ユーザーは何を止められたか分からなくなる。
REASON=$(jq -nc '{tool_input:{command:"vault kv put secret/a b=c"},cwd:"/tmp"}' \
  | bash "$BASH_GUARD" | jq -r '.hookSpecificOutput.permissionDecisionReason')
if printf '%s' "$REASON" | grep -q "HashiCorp Vaultへの書き込み"; then
  _ok "deny の理由に deny-rules.txt の説明が含まれる"
else
  _ng "deny の理由から説明が欠落している: $REASON"
fi

echo ""
echo "PASS: $PASS / FAIL: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
