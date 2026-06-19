#!/usr/bin/env bash
# verify-package-install.sh の回帰テスト
#
# 守りたい不変条件:
#   1. npm install <pkg> / pnpm add <pkg> / yarn add <pkg>（及び sfw ラップ）の
#      パッケージ指定ありコマンドは検証フラグが無ければ deny する。
#   2. パッケージ指定なし（npm ci / npm install 単体など）は通過させる。
#   3. 引数本文に該当文字列が含まれるだけのコマンド（gh pr create --body / git commit -m
#      など）は誤検知しない。HEREDOC・複数引用符を含む形でも誤検知しない。
#   4. Python（bashlex）経路と bash フォールバック経路の両方で 1〜3 を満たす。
#      hook 変更時に片方の経路だけ壊すと PR が落ちる。
#
# 使い方:
#   bash claude/tests/verify-package-install.test.sh
# 環境変数:
#   VERIFY_HOOK_TEST_ONLY=python|bash で片方の経路だけ実行する（CI から個別に呼ぶ用）。
# 終了コード: 0=全テスト成功 / 1=失敗あり

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HOOK="$SCRIPT_DIR/../hooks/pre-tool-use/verify-package-install.sh"

PASS=0
FAIL=0

# 検証フラグディレクトリを一時退避（既存フラグの影響を遮断）
EMPTY_HOME=$(mktemp -d)
trap 'rm -rf "$EMPTY_HOME"' EXIT

_decision() {
  local cmd="$1" output
  local input
  input=$(jq -n --arg c "$cmd" '{tool_input:{command:$c}}')
  output=$(HOME="$EMPTY_HOME" printf '%s' "$input" | HOME="$EMPTY_HOME" bash "$HOOK" 2>/dev/null)
  if [[ -z "$output" ]]; then
    echo "pass"
  else
    echo "$output" | jq -r '.hookSpecificOutput.permissionDecision // "pass"'
  fi
}

_run() {
  local desc="$1" cmd="$2" expect="$3"
  local got
  got=$(_decision "$cmd")
  if [[ "$got" == "$expect" ]]; then
    PASS=$((PASS+1))
    printf "  OK   %-50s [%s]\n" "$desc" "$got"
  else
    FAIL=$((FAIL+1))
    printf "  FAIL %-50s expected=%s got=%s\n" "$desc" "$expect" "$got"
    printf "       cmd: %s\n" "$cmd"
  fi
}

_run_all_cases() {
  echo "  -- DENY 想定（install 系を検知すべき） --"
  _run "npm install version指定"        "npm install lodash@4.17.21" "deny"
  _run "npm i 短縮形"                   "npm i lodash@4.17.21" "deny"
  _run "pnpm add"                       "pnpm add lodash@4.17.21" "deny"
  _run "yarn add"                       "yarn add lodash@4.17.21" "deny"
  _run "sfw npm install"                "sfw npm install lodash@4.17.21" "deny"
  _run "バージョン未指定"               "npm install lodash" "deny"
  _run "スコープ付き version 未指定"    "npm install @scope/pkg" "deny"
  _run "スコープ付き version 指定"      "npm install @scope/pkg@1.0.0" "deny"
  _run "cd && npm install"              "cd packages/foo && npm install bar@1.0.0" "deny"
  _run "git pull && npm install"        "git pull && npm install lodash@4.17.21" "deny"
  _run "-D フラグ後に pkg"              "npm install -D typescript@5.0.0" "deny"

  echo "  -- PASS 想定（誤検知してはいけない） --"
  _run "npm ci"                         "npm ci" "pass"
  _run "pnpm install --frozen-lockfile" "pnpm install --frozen-lockfile" "pass"
  _run "yarn install --immutable"       "yarn install --immutable" "pass"
  _run "対象外コマンド"                 "ls -la" "pass"
  _run "gh pr create --body 内に文字列" 'gh pr create --body "本文に npm install が含まれる説明"' "pass"
  _run "git commit -m 内に文字列"       'git commit -m "fix: npm install を呼ぶスクリプトの説明"' "pass"
  _run "git commit -m 内に &&"          'git commit -m "本文 && npm install lodash も触れる"' "pass"
  _run "git commit HEREDOC 内に install" 'git commit -m "$(cat <<EOF
本文 && npm install lodash の話
コード例: npm install foo@1.0.0
EOF
)"' "pass"
  _run "git commit HEREDOC quoted マーカー" "git commit -m \"\$(cat <<'EOF'
複数引用 \"foo\" を含む && npm install bar 説明
EOF
)\"" "pass"
  _run "git commit HEREDOC dash"        'git commit -m "$(cat <<-EOF
	インデント許可 && npm install zzz
	EOF
)"' "pass"
  _run "echo 文字列"                    'echo "npm install foo"' "pass"
  _run "対象外サブコマンド npm run"     "npm run build" "pass"
  _run "対象外サブコマンド pnpm dlx"    "pnpm dlx some-cli" "pass"
}

run_python_path() {
  local venv="$HOME/.local/share/bashlex-venv/bin/python3"
  if [[ ! -x "$venv" ]]; then
    echo "[SKIP] Python 経路: $venv が見つかりません（venv 未セットアップ）"
    return 0
  fi
  if ! "$venv" -c 'import bashlex' 2>/dev/null; then
    echo "[SKIP] Python 経路: venv に bashlex が入っていません"
    return 0
  fi
  echo "=== Python 経路（bashlex） ==="
  VERIFY_HOOK_PARSER_PYTHON="$venv" _run_all_cases
}

run_bash_path() {
  echo "=== bash フォールバック経路 ==="
  VERIFY_HOOK_PARSER_PYTHON="" _run_all_cases
}

only="${VERIFY_HOOK_TEST_ONLY:-both}"
case "$only" in
  python) run_python_path ;;
  bash)   run_bash_path ;;
  both)   run_python_path; run_bash_path ;;
  *) echo "VERIFY_HOOK_TEST_ONLY は python / bash / both のいずれか"; exit 2 ;;
esac

echo "----"
printf '成功 %d / 失敗 %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
