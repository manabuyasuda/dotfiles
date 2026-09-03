#!/usr/bin/env bash
# hook の判定メッセージの長さに関する回帰テスト
#
# 守りたい不変条件は3つ。
#   1. 判定メッセージの長さが、判定対象ではなく判定結果で決まる。
#      どれだけ長い入力を渡しても、理由文は上限文字数以内で改行を含まない。
#   2. 実際の hook（bash-guard / dangerous-guard / file-protect）が
#      長大な入力を受けても、その不変条件を満たす。
#   3. 判定 JSON を出力する hook は、自前の jq ではなく lib/decision.sh を通る。
#      合流点を迂回した hook が増えると、1と2を強制できなくなる。
#
# WHY: 55行のヒアドキュメントを deny したとき、コマンド全文を埋めた55行の理由文が
#      画面を流し、直後の承認ダイアログがユーザーの視界の外へ出た（2026-08-31）。
#      ユーザーは待ちに気づけず、同じ文字列がコンテキストも二重に消費した。
#
# 使い方: bash claude/tests/hook-decision.test.sh
# 終了コード 0=全テスト成功 / 1=失敗あり

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
HOOKS="$ROOT/claude/hooks"

# shellcheck source=../hooks/lib/decision.sh
source "$HOOKS/lib/decision.sh"

PASS=0
FAIL=0
_ok() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
_ng() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# 理由文の文字数（コードポイント）。bash の ${#s} はロケール依存なので jq で数える。
_reason_len() { printf '%s' "$1" | jq '.hookSpecificOutput.permissionDecisionReason | length'; }
_reason() { printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason'; }

# 上限以内かつ1行であることを確かめる
_expect_bounded() { # $1=ラベル $2=hook の出力JSON
  local label="$1" out="$2" len reason
  if [ -z "$out" ]; then
    _ng "$label: 出力が空（判定されていない）"
    return
  fi
  len=$(_reason_len "$out")
  reason=$(_reason "$out")
  if [ "$len" -gt "$HOOK_DECISION_MAX_CHARS" ]; then
    _ng "$label: 理由文が ${len} 文字（上限 ${HOOK_DECISION_MAX_CHARS}）"
  elif [ "$(printf '%s' "$reason" | wc -l | tr -d ' ')" != "0" ]; then
    _ng "$label: 理由文に改行が残っている"
  else
    _ok "$label: ${len} 文字・1行"
  fi
}

# 改行を含む長大な入力（約4500文字）
LONG_TAIL=$(printf '# あいうえお填め字%.0s\n' {1..300})

# hook を実行して判定 JSON を返す
_run_bash_hook() { # $1=hookのパス $2=コマンド
  jq -nc --arg c "$2" '{tool_input:{command:$c},cwd:"/tmp"}' | bash "$1"
}

echo "T1: lib/decision.sh はどれだけ長い入力でも上限内の1行を返す"
_expect_bounded "hook_emit_decision(deny)" "$(hook_emit_decision deny PreToolUse "ERROR: テスト。$LONG_TAIL")"
_expect_bounded "hook_emit_decision(ask)" "$(hook_emit_decision ask PreToolUse "CAUTION: テスト。$LONG_TAIL")"

echo "T2: 短いメッセージは切り詰めず、そのまま返る"
GOT=$(hook_emit_decision deny PreToolUse "ERROR: 短い理由。" | jq -r '.hookSpecificOutput.permissionDecisionReason')
if [ "$GOT" = "ERROR: 短い理由。" ]; then _ok "短い理由文は無加工"; else _ng "短い理由文が変わった: $GOT"; fi

echo "T3: hook_excerpt は1行の抜粋にし、省略した事実を残す"
GOT=$(hook_excerpt "$LONG_TAIL")
LEN=$(printf '%s' "$GOT" | jq -Rs 'rtrimstr("\n") | length')
if [ "$LEN" -le "$HOOK_EXCERPT_MAX_CHARS" ] && printf '%s' "$GOT" | grep -q '文字）'; then
  _ok "抜粋は ${LEN} 文字で、全体の文字数が付く"
else
  _ng "抜粋が上限を超えるか、省略の表示がない（${LEN} 文字）: $GOT"
fi
GOT=$(hook_excerpt "cat /tmp/a.txt")
if [ "$GOT" = "cat /tmp/a.txt" ]; then _ok "短い入力は無加工"; else _ng "短い入力が変わった: $GOT"; fi

echo "T4: 実際の hook が長大な入力を受けても上限内の1行を返す"
# bash-guard: deny-rules.txt の PATH ルールに一致する秘密ファイルの読み取り
_expect_bounded "bash-guard(deny)" \
  "$(_run_bash_hook "$HOOKS/pre-tool-use/bash-guard.sh" "cat ~/.aws/credentials
$LONG_TAIL")"
# bash-guard: classify() の ask（DESTRUCTIVE）
_expect_bounded "bash-guard(ask)" \
  "$(_run_bash_hook "$HOOKS/pre-tool-use/bash-guard.sh" "git reset --hard HEAD~1
$LONG_TAIL")"
# dangerous-guard: 再帰削除の deny
_expect_bounded "dangerous-guard(deny)" \
  "$(_run_bash_hook "$HOOKS/pre-tool-use/dangerous-guard.sh" "rm -rf /tmp/dummy-target
$LONG_TAIL")"
# file-protect: Write の deny（長大なパス）
LONG_PATH="/tmp/$(printf 'd/%.0s' {1..400}).env.local"
_expect_bounded "file-protect(deny)" \
  "$(jq -nc --arg p "$LONG_PATH" '{tool_name:"Write",tool_input:{file_path:$p,path:$p},cwd:"/tmp"}' |
    bash "$HOOKS/pre-tool-use/file-protect.sh")"

echo "T5: 判定 JSON を出力する hook は lib/decision.sh を経由する"
# 自前で jq を書くと上限を強制する場所がなくなるため、迂回をここで落とす。
BYPASS=0
while IFS= read -r f; do
  if grep -q 'hookSpecificOutput' "$f" && grep -q 'jq -n' "$f"; then
    echo "  -> 迂回: ${f#"$ROOT"/}"
    BYPASS=$((BYPASS + 1))
  fi
done < <(find "$HOOKS/pre-tool-use" "$HOOKS/post-tool-use" -name '*.sh')
if [ "$BYPASS" -eq 0 ]; then
  _ok "自前で判定 JSON を組み立てる hook はない"
else
  _ng "${BYPASS} 個の hook が lib/decision.sh を迂回している"
fi

echo "T6: 長さに上限のない入力は hook_excerpt で抑え、理由文の末尾が切られない"
# 理由文の可変部分を hook_excerpt に通し忘れると、上限に当たったとき lib/decision.sh が
# 末尾から切る。末尾には「何を対象に何をすればよいか」が置かれているため、定型の手順文
# だけが残って対象が分からない状態になる。
# verify-package-install.sh のパッケージ一覧が、その唯一の該当箇所だった（2026-09-02）。
# 判定は末尾の記号で見分ける。
#   「…（全N文字）」 = hook_excerpt が抜粋した（意図した省略）
#   「…（以下省略）」 = lib/decision.sh が最後の砦として切った（抜粋の通し忘れ）
MANY_PKGS=""
for i in $(seq 1 30); do
  MANY_PKGS+=" @scope/very-long-package-name-for-testing-${i}"
done
REASON=$(jq -nc --arg c "npm install$MANY_PKGS" '{tool_input:{command:$c},cwd:"/tmp"}' |
  bash "$HOOKS/pre-tool-use/verify-package-install.sh" |
  jq -r '.hookSpecificOutput.permissionDecisionReason // ""')
if [ -z "$REASON" ]; then
  _ng "verify-package-install が deny を返さない（テストの前提が崩れている）"
elif printf '%s' "$REASON" | grep -q "以下省略"; then
  _ng "理由文が末尾から切られている（パッケージ一覧を hook_excerpt に通してください）"
elif ! printf '%s' "$REASON" | grep -q "本コマンドを再実行する"; then
  _ng "理由文から FIX の手順が欠落している: $REASON"
else
  _ok "パッケージ一覧が抜粋され、手順が理由文に残る"
fi


echo ""
echo "PASS: $PASS / FAIL: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
